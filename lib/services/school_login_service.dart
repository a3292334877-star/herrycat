import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// 深圳职业技术大学教务系统登录与课表抓取服务
class SchoolLoginService {
  static const String _baseUrl = 'https://jwxt.szpu.edu.cn';

  String? _sessionId;
  String _cookies = '';

  /// 登录（带详细调试信息）
  Future<bool> login(String username, String password) async {
    final log = <String>[];

    // ── 0. 连通性检查 ──
    try {
      final connResp = await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 6));
      log.add('✓ 教务服务器可达 (HTTP ${connResp.statusCode})');
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('socke') || msg.contains('dns') || msg.contains('refused')) {
        throw Exception(
            '❌ 无法访问教务系统\n\n'
            '请确认手机已连接 深职院Campus WiFi\n'
            '或已启用深职院VPN\n\n'
            '(当前网络无法到达 jwxt.szpu.edu.cn)');
      }
      log.add('⚠ 连通检查异常: ${e.message}');
    } catch (e) {
      log.add('⚠ 连通检查超时/异常: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}');
    }

    // ── 1. RSA 公钥 ──
    String? modulus;
    String exponentHex = '10001';
    for (final keyPath in [
      '/jwapp/sys/emaphome/getRSAKey.do',
      '/jwapp/sys/emaphome/getRSAKey',
      '/jwapp/sys/login/getRSAKey',
    ]) {
      try {
        final preResp = await http
            .get(Uri.parse('$_baseUrl$keyPath'), headers: _headers)
            .timeout(const Duration(seconds: 8));
        final body = preResp.body.trim();
        if (body.isEmpty) { log.add('  RSA $keyPath → 空响应'); continue; }
        if (body.startsWith('<') || !body.startsWith('{')) {
          log.add('  RSA $keyPath → 非JSON (${body.length > 60 ? '${body.substring(0, 60)}...' : body})');
          continue;
        }
        final preData = jsonDecode(body);
        final keyData = preData['data'] ?? preData;
        modulus = keyData['modulus'] ?? keyData['key'] ?? keyData['publicKey'] ?? '';
        exponentHex = keyData['exponent'] ?? '10001';
        if (modulus != null && modulus.isNotEmpty) {
          log.add('✓ 获取RSA公钥成功 ($keyPath)');
          break;
        }
      } catch (e) {
        log.add('  RSA $keyPath → ${e.toString().length > 60 ? e.toString().substring(0, 60) : e}');
      }
    }
    if (modulus == null || modulus.isEmpty) log.add('⚠ 未获取到RSA公钥');

    // ── 2. 加密 ──
    String? encryptedPwd;
    if (modulus != null && modulus.isNotEmpty) {
      try {
        encryptedPwd = _rsaEncrypt(password, modulus, exponentHex);
        log.add('✓ RSA密码加密完成');
      } catch (e) {
        log.add('✗ RSA加密失败: $e');
      }
    }

    // ── 3. 登录 — 多策略 ──
    final loginPaths = [
      '/jwapp/sys/emaphome/login.do',
      '/jwapp/sys/emaphome/login',
      '/jwapp/sys/login',
    ];

    // 策略 A: JSON + RSA
    if (encryptedPwd != null) {
      for (final path in loginPaths) {
        final result = await _tryLogin(
            path, username, encryptedPwd, 'RSA-JSON', _headers, log);
        if (result != null) {
          _sessionId = result.sessionId;
          _cookies = result.cookies;
          return true;
        }
      }
    }

    // 策略 B: JSON + 明文
    for (final path in loginPaths) {
      final result = await _tryLogin(
          path, username, password, '明文-JSON', _headers, log);
      if (result != null) {
        _sessionId = result.sessionId;
        _cookies = result.cookies;
        return true;
      }
    }

    // 策略 C: form-urlencoded
    for (final path in loginPaths) {
      final formHeaders = {
        ..._headers,
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      };
      final formBody =
          'loginName=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}';
      final result = await _tryLogin(
          path, username, formBody, 'Form', formHeaders, log, isRawBody: true);
      if (result != null) {
        _sessionId = result.sessionId;
        _cookies = result.cookies;
        return true;
      }
    }

    // ── 失败，输出日志 ──
    throw Exception('登录失败\n\n${log.join('\n')}');
  }

  /// 尝试一次登录，成功返回 session 信息，失败返回 null
  Future<_LoginResult?> _tryLogin(
    String path,
    String username,
    dynamic bodyOrPwd,
    String label,
    Map<String, String> headers,
    List<String> log, {
    bool isRawBody = false,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: headers,
        body: isRawBody ? bodyOrPwd : jsonEncode({
          'loginName': username,
          'password': bodyOrPwd,
        }),
      ).timeout(const Duration(seconds: 12));

      final body = resp.body.trim();
      final statusCode = resp.statusCode;

      // 302 = CAS 跳转/登录成功
      if (statusCode == 302) {
        final loc = resp.headers['location'] ?? '';
        log.add('  $label $path → HTTP 302${loc.isNotEmpty ? ' → $loc' : ''}');
        // 尝试从重定向提取 session
        final cookies = _extractCookies(resp);
        if (cookies.isNotEmpty) {
          log.add('✓ $label 登录成功 (302 + cookie)');
          return _LoginResult(sessionId: '', cookies: cookies);
        }
      }

      if (body.isEmpty) {
        log.add('  $label $path → HTTP $statusCode 空响应');
        return null;
      }

      // HTML 响应
      if (body.startsWith('<')) {
        final snippet = body.length > 80 ? body.substring(0, 80) : body;
        log.add('  $label $path → HTTP $statusCode HTML(${snippet.replaceAll('\n', ' ')}...)');
        return null;
      }

      // JSON 响应
      if (body.startsWith('{')) {
        try {
          final data = jsonDecode(body);
          final code = data['code'];
          final success = code == '0' || code == 0 ||
              data['success'] == true || data['success'] == 'true';

          if (success) {
            final cookies = _extractCookies(resp);
            final jsessionMatch =
                RegExp(r'JSESSIONID=([^;]+)').firstMatch(cookies);
            final token = data['data']?['token'] ??
                data['token'] ??
                jsessionMatch?.group(1) ??
                '';
            log.add('✓ $label 登录成功 ($path)');
            return _LoginResult(sessionId: token, cookies: cookies);
          }

          final msg = data['msg'] ?? data['message'] ?? data['error'] ?? '未知错误';
          log.add('  $label $path → 失败: $msg');
          return null;
        } catch (_) {}
      }

      log.add('  $label $path → HTTP $statusCode 未知格式(${body.length}b)');
    } catch (e) {
      final errStr = e.toString();
      final short = errStr.length > 80 ? '${errStr.substring(0, 80)}...' : errStr;
      log.add('  $label $path → 异常: $short');
    }
    return null;
  }

  /// 提取所有 Cookie
  String _extractCookies(http.Response resp) {
    final cookieHeader = resp.headers['set-cookie'] ?? '';
    if (cookieHeader.isEmpty) return '';

    final cookies = <String>[];
    for (final part in cookieHeader.split(',')) {
      final trimmed = part.trim();
      final semiIdx = trimmed.indexOf(';');
      final kv = semiIdx > 0 ? trimmed.substring(0, semiIdx) : trimmed;
      if (kv.contains('=')) cookies.add(kv);
    }
    return cookies.join('; ');
  }

  /// RSA 加密（PKCS1v15，真随机填充）
  String _rsaEncrypt(String plaintext, String modulusHex, String exponentHex) {
    final n = BigInt.parse(modulusHex, radix: 16);
    final e = BigInt.parse(exponentHex, radix: 16);
    final keyByteLen = (n.bitLength + 7) >> 3;

    final psLen = keyByteLen - plaintext.length - 3;
    if (psLen < 8) throw Exception('密码过长，RSA密钥不足');

    final rng = Random.secure();
    final ps = List<int>.generate(psLen, (_) {
      int b;
      do { b = rng.nextInt(256); } while (b == 0);
      return b;
    });

    final t = utf8.encode(plaintext);
    final em = [0x00, 0x02, ...ps, 0x00, ...t];

    final m = _bytesToBigInt(em);
    final c = _modexp(m, e, n);
    return _bigIntToHex(c);
  }

  BigInt _bytesToBigInt(List<int> bytes) {
    BigInt result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) + BigInt.from(b);
    }
    return result;
  }

  String _bigIntToHex(BigInt v) {
    final hex = v.toRadixString(16);
    return hex.length.isOdd ? '0$hex' : hex;
  }

  BigInt _modexp(BigInt base, BigInt exp, BigInt mod) {
    BigInt result = BigInt.one;
    BigInt b = base;
    BigInt e = exp;
    while (e > BigInt.zero) {
      if (e & BigInt.one == BigInt.one) result = (result * b) % mod;
      b = (b * b) % mod;
      e >>= 1;
    }
    return result;
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Content-Type': 'application/json; charset=UTF-8',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    'X-Requested-With': 'XMLHttpRequest',
    'Origin': _baseUrl,
    'Referer': '$_baseUrl/jwapp/sys/emaphome/',
  };

  /// 抓取课表
  Future<List<Map<String, dynamic>>> fetchSchedule() async {
    if ((_sessionId == null || _sessionId!.isEmpty) && _cookies.isEmpty) {
      throw Exception('未登录，请先调用 login()');
    }

    final termCode = await _getCurrentTerm();
    final errors = <String>[];

    http.Response? resp;
    for (final schedulePath in [
      '/jwapp/sys/kcbcxmdl/modules/qxkcp/qxkccxx.do',
      '/jwapp/sys/kcbcxmdl/modules/qxkcp/qxkccxx',
      '/jwapp/sys/kcbcxmdl/modules/qxkcp/queryKccxx',
      '/jwapp/sys/kcbcxmdl/modules/qxkccxx/qxkccxx.do',
      '/jwapp/sys/kcbcxmdl/modules/qxkcb/qxkccxx.do',
    ]) {
      try {
        final r = await http.post(
          Uri.parse('$_baseUrl$schedulePath'),
          headers: {
            ..._headers,
            if (_cookies.isNotEmpty) 'Cookie': _cookies,
          },
          body: jsonEncode({
            'XNXQDM': termCode,
            '*json': '1',
            'querySetting': jsonEncode([
              {'name': 'XNXQDM', 'value': termCode, 'linkOpt': 'and', 'builder': 'equal'},
            ]),
            '*order': '+KCH,+KXH,-SKZC,+SKXQ,+SKJC',
          }),
        ).timeout(const Duration(seconds: 30));

        final body = r.body.trim();
        if (body.isEmpty) continue;
        if (body.startsWith('<') || !body.startsWith('{')) continue;

        resp = r;
        break;
      } catch (e) {
        errors.add('$schedulePath: $e');
      }
    }

    if (resp == null) {
      final detail = errors.isNotEmpty
          ? '\n尝试的路径:\n${errors.take(3).map((e) => '  • $e').join('\n')}'
          : '';
      throw Exception('获取课表失败，可能会话已过期请重新登录$detail');
    }

    if (resp.statusCode != 200) {
      throw Exception('获取课表失败，HTTP ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body);
    final code = data['code'];
    final success = code == '0' || code == 0 ||
        data['success'] == true || data['success'] == 'true';

    if (!success && code != null) {
      final msg = data['msg'] ?? data['message'] ?? '获取课表失败';
      throw Exception(msg);
    }

    final rows = data['datas']?['qxkccxx']?['rows'] ??
        data['data']?['rows'] ??
        data['datas']?['rows'] ??
        data['rows'];

    if (rows == null) return [];
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<String> _getCurrentTerm() async {
    for (final termPath in [
      '/jwapp/sys/emaphome/getQXQDMCurrent.do',
      '/jwapp/sys/emaphome/getQXQDMCurrent',
      '/jwapp/sys/emaphome/getCurrentTerm',
    ]) {
      try {
        final resp = await http.get(
          Uri.parse('$_baseUrl$termPath'),
          headers: {
            ..._headers,
            if (_cookies.isNotEmpty) 'Cookie': _cookies,
          },
        ).timeout(const Duration(seconds: 10));
        final body = resp.body.trim();
        if (!body.startsWith('{')) continue;
        final data = jsonDecode(body);
        final term = data['data']?['QXXQDM'] ??
            data['data']?['qxxqdm'] ??
            data['QXXQDM'] ?? '';
        if (term.isNotEmpty) return term;
      } catch (_) {}
    }
    return '2025-2026-2';
  }
}

class _LoginResult {
  final String sessionId;
  final String cookies;
  const _LoginResult({required this.sessionId, required this.cookies});
}

/// 从 SKJC 字段（如 "5-6节"）解析起始和结束节次
(int start, int end) parseSectionRange(String skjc) {
  final match = RegExp(r'(\d+)-(\d+)节').firstMatch(skjc);
  if (match != null) {
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }
  final single = RegExp(r'(\d+)节').firstMatch(skjc);
  if (single != null) {
    final s = int.parse(single.group(1)!);
    return (s, s);
  }
  return (1, 2);
}

/// 从 SKZC 字段（如 "2-16周(双)"）解析周次信息
({String startWeek, String endWeek, bool? isOddWeek}) parseWeekInfo(String skzc) {
  final oddMatch = RegExp(r'(\d+)-(\d+)周\(单\)').firstMatch(skzc);
  if (oddMatch != null) {
    return (
      startWeek: oddMatch.group(1)!,
      endWeek: oddMatch.group(2)!,
      isOddWeek: true,
    );
  }
  final evenMatch = RegExp(r'(\d+)-(\d+)周\(双\)').firstMatch(skzc);
  if (evenMatch != null) {
    return (
      startWeek: evenMatch.group(1)!,
      endWeek: evenMatch.group(2)!,
      isOddWeek: false,
    );
  }
  final rangeMatch = RegExp(r'(\d+)-(\d+)周').firstMatch(skzc);
  if (rangeMatch != null) {
    return (
      startWeek: rangeMatch.group(1)!,
      endWeek: rangeMatch.group(2)!,
      isOddWeek: null,
    );
  }
  final singleMatch = RegExp(r'(\d+)周').firstMatch(skzc);
  if (singleMatch != null) {
    return (startWeek: singleMatch.group(1)!, endWeek: singleMatch.group(1)!, isOddWeek: null);
  }
  return (startWeek: '1', endWeek: '16', isOddWeek: null);
}
