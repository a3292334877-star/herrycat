import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// 深圳职业技术大学教务系统登录与课表抓取服务
/// 适配新版正方教务系统（2026）
class SchoolLoginService {
  static const String _baseUrl = 'https://jwxt.szpu.edu.cn';

  String _cookies = '';

  /// 登录
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
            '或已启用深职院VPN');
      }
      log.add('⚠ 连通检查: ${e.message}');
    } catch (e) {
      log.add('⚠ 连通检查: $e');
    }

    // ── 0.5 获取初始 Session（新版教务需要先访问首页拿 cookie） ──
    await _getInitialSession(log);

    // ── 1. RSA 公钥（新版路径 + 旧版路径 + 从HTML提取） ──
    String? modulus;
    String exponentHex = '10001';

    // 新版教务 API 路径
    for (final keyPath in [
      '/jwglxt/xtgl/login_getPublicKey.html',
      '/jwglxt/xtgl/login_getPublicKey',
      '/jwglxt/xtgl/login/login_getPublicKey.html',
      '/jwapp/sys/emaphome/getRSAKey.do',
      '/jwapp/sys/emaphome/getRSAKey',
      '/jwapp/sys/login/getRSAKey',
    ]) {
      try {
        final preResp = await http
            .get(Uri.parse('$_baseUrl$keyPath'), headers: _cookiesHeader)
            .timeout(const Duration(seconds: 8));

        final body = preResp.body.trim();
        if (body.isEmpty) continue;

        // 尝试 JSON 解析
        if (body.startsWith('{')) {
          final preData = jsonDecode(body);
          modulus = preData['modulus'] ?? preData['data']?['modulus'] ?? '';
          exponentHex = preData['exponent'] ?? preData['data']?['exponent'] ?? '10001';
          if (modulus != null && modulus.isNotEmpty) {
            log.add('✓ RSA公钥 ($keyPath)');
            break;
          }
        }
      } catch (_) {}
    }

    // ── 1.5 从登录页面 HTML 提取 RSA 公钥（新版正方常用方式） ──
    if (modulus == null || modulus.isEmpty) {
      try {
        final pageResp = await http
            .get(Uri.parse('$_baseUrl/jwglxt/xtgl/login_slogin.html'),
                headers: _cookiesHeader)
            .timeout(const Duration(seconds: 8));
        final html = pageResp.body;
        // 正方新版：var modulus = '...'; var exponent = '...';
        // 匹配 modulus='xxx' 或 modulus="xxx"
        final modMatch = RegExp(r"modulus\s*=\s*'([^']+)'").firstMatch(html) ??
            RegExp(r'modulus\s*=\s*"([^"]+)"').firstMatch(html);
        final expMatch = RegExp(r"exponent\s*=\s*'([^']+)'").firstMatch(html) ??
            RegExp(r'exponent\s*=\s*"([^"]+)"').firstMatch(html);
        if (modMatch != null) {
          modulus = modMatch.group(1)!;
          if (expMatch != null) exponentHex = expMatch.group(1)!;
          log.add('✓ 从HTML提取RSA公钥');
        }
      } catch (_) {}
    }

    if (modulus == null || modulus.isEmpty) {
      log.add('⚠ 未获取到RSA公钥，将使用明文密码');
    }

    // ── 2. 加密 ──
    String? encryptedPwd;
    if (modulus != null && modulus.isNotEmpty) {
      try {
        encryptedPwd = _rsaEncrypt(password, modulus, exponentHex);
        log.add('✓ RSA加密完成');
      } catch (e) {
        log.add('✗ RSA加密失败: $e');
      }
    }

    // ── 3. 登录（新版 /jwglxt/ + 旧版 /jwapp/） ──
    // 新版正方登录接口
    final loginPaths = [
      ('/jwglxt/xtgl/login_slogin.html', 'new-web'),
      ('/jwapp/sys/emaphome/login.do', 'old-api'),
      ('/jwapp/sys/emaphome/login', 'old-api'),
    ];

    // 策略 A: RSA加密
    if (encryptedPwd != null) {
      for (final (path, label) in loginPaths) {
        final result = await _tryLogin(
            path, label, username, encryptedPwd, true, log);
        if (result != null) {
          _cookies = result.cookies;
          return true;
        }
      }
    }

    // 策略 B: 明文
    for (final (path, label) in loginPaths) {
      final result = await _tryLogin(
          path, label, username, password, false, log);
      if (result != null) {
        _cookies = result.cookies;
        return true;
      }
    }

    throw Exception('登录失败\n\n${log.join('\n')}');
  }

  /// 获取初始 Session Cookie
  Future<void> _getInitialSession(List<String> log) async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/jwglxt/xtgl/login_slogin.html'),
              headers: _headers)
          .timeout(const Duration(seconds: 8));
      final cookies = _extractCookies(resp);
      if (cookies.isNotEmpty) {
        _cookies = cookies;
        log.add('✓ 获取初始Session');
      }
    } catch (_) {
      // 非致命
    }
  }

  /// 尝试一次登录
  Future<_LoginResult?> _tryLogin(
    String path,
    String label,
    String username,
    String password,
    bool isEncrypted,
    List<String> log,
  ) async {
    // 新版正方登录需要特殊格式的 body
    final bodies = <String, dynamic>{};
    if (label == 'new-web') {
      // 新版正方 web 登录格式
      bodies.addAll({
        'yhm': username,
        if (isEncrypted) 'mm': password else 'mm': password,
        'mm': password, // 新版正方字段名是 yhm/mm 或 loginName/password
      });
    }
    // 旧版 API 格式
    final oldBodies = {
      'loginName': username,
      'password': password,
    };

    // 尝试多种 body 格式
    final bodyVariants = [
      if (label == 'new-web') bodies,
      if (label == 'new-web') oldBodies,
      oldBodies,
    ];

    for (final body in {...bodyVariants}) {
      try {
        final resp = await http.post(
          Uri.parse('$_baseUrl$path'),
          headers: _cookiesHeader,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 12));

        final respBody = resp.body.trim();
        final code = resp.statusCode;

        // 302 / 重定向 = 成功
        if (code == 302) {
          final newCookies = _extractCookies(resp);
          log.add('✓ $label 登录成功 (HTTP 302)');
          return _LoginResult(
            sessionId: _extractToken(resp, ''),
            cookies: _mergeCookies(_cookies, newCookies),
          );
        }

        // JSON 响应
        if (respBody.startsWith('{')) {
          try {
            final data = jsonDecode(respBody);
            final isSuccess = data['code'] == '0' || data['code'] == 0 ||
                data['status'] == 'success' || data['success'] == true;

            if (isSuccess) {
              final newCookies = _extractCookies(resp);
              final token = _extractToken(resp, data);
              log.add('✓ $label 登录成功');
              return _LoginResult(
                sessionId: token,
                cookies: _mergeCookies(_cookies, newCookies),
              );
            }

            final msg = data['msg'] ?? data['message'] ?? data['error'] ?? '未知错误';
            log.add('  $label → $msg');
          } catch (_) {}
          continue;
        }

        // HTML 401 = 认证失败
        if (code == 401) {
          log.add('  $label → HTTP 401 认证失败（可能是密码错误或接口需要特殊格式）');
          continue;
        }

        if (code == 404) {
          log.add('  $label → HTTP 404 接口不存在');
          continue;
        }

        log.add('  $label → HTTP $code (${respBody.length}b)');
      } catch (e) {
        final s = e.toString().length > 80
            ? '${e.toString().substring(0, 80)}...'
            : e.toString();
        log.add('  $label → 异常: $s');
      }
    }

    return null;
  }

  String _extractToken(http.Response resp, dynamic data) {
    if (data is Map) {
      return data['data']?['token'] ?? data['token'] ?? data['sessionid'] ?? '';
    }
    final cookies = resp.headers['set-cookie'] ?? '';
    final m = RegExp(r'JSESSIONID=([^;]+)').firstMatch(cookies);
    return m?.group(1) ?? '';
  }

  String _mergeCookies(String old, String add) {
    if (add.isEmpty) return old;
    if (old.isEmpty) return add;
    return '$old; $add';
  }

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

  /// RSA 加密（PKCS1v15）
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
    'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    'X-Requested-With': 'XMLHttpRequest',
    'Origin': _baseUrl,
    'Referer': '$_baseUrl/jwglxt/xtgl/login_slogin.html',
  };

  Map<String, String> get _cookiesHeader => {
    ..._headers,
    if (_cookies.isNotEmpty) 'Cookie': _cookies,
  };

  /// 抓取课表
  Future<List<Map<String, dynamic>>> fetchSchedule() async {
    if (_cookies.isEmpty) {
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
      '/jwglxt/kbcx/xskbcx_cxXsKb.html',
    ]) {
      try {
        // 新版正方用 GET + 参数，旧版用 POST + JSON
        http.Response r;
        if (schedulePath.contains('jwglxt')) {
          // 新版正方课表查询
          r = await http.post(
            Uri.parse('$_baseUrl$schedulePath'),
            headers: _cookiesHeader,
            body: 'xnm=${termCode.substring(0, 4)}&xqm=${_termToXqm(termCode)}&kzlx=ck',
          ).timeout(const Duration(seconds: 30));
        } else {
          r = await http.post(
            Uri.parse('$_baseUrl$schedulePath'),
            headers: _cookiesHeader,
            body: jsonEncode({
              'XNXQDM': termCode,
              '*json': '1',
              'querySetting': jsonEncode([
                {'name': 'XNXQDM', 'value': termCode, 'linkOpt': 'and', 'builder': 'equal'},
              ]),
              '*order': '+KCH,+KXH,-SKZC,+SKXQ,+SKJC',
            }),
          ).timeout(const Duration(seconds: 30));
        }

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
          ? '\n${errors.take(3).map((e) => '  • $e').join('\n')}'
          : '';
      throw Exception('获取课表失败，可能会话已过期$detail');
    }

    final data = jsonDecode(resp.body);

    // 新版正方响应格式
    var rows = data['datas']?['qxkccxx']?['rows'] ??
        data['data']?['rows'] ??
        data['datas']?['rows'] ??
        data['rows'] ??
        data;

    // 如果是 List 直接就是课表数据
    if (rows is List) return rows.cast<Map<String, dynamic>>();
    return [];
  }

  String _termToXqm(String termCode) {
    // termCode like "2025-2026-2" → xqm = "3" for second semester
    // or "12" depending on system
    final parts = termCode.split('-');
    if (parts.length >= 3) {
      final sem = parts[2];
      // 新版正方: 1="3"(上学期), 2="12"(下学期), 3="16"(暑假)
      switch (sem) {
        case '1': return '3';
        case '2': return '12';
        case '3': return '16';
      }
    }
    return '12'; // default to semester 2
  }

  Future<String> _getCurrentTerm() async {
    for (final termPath in [
      '/jwapp/sys/emaphome/getQXQDMCurrent.do',
      '/jwapp/sys/emaphome/getQXQDMCurrent',
      '/jwapp/sys/emaphome/getCurrentTerm',
      '/jwglxt/xtgl/index_initMenu.html',
    ]) {
      try {
        final resp = await http
            .get(Uri.parse('$_baseUrl$termPath'), headers: _cookiesHeader)
            .timeout(const Duration(seconds: 10));
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

/// 从 SKJC 字段解析节次
(int start, int end) parseSectionRange(String skjc) {
  final match = RegExp(r'(\d+)-(\d+)节').firstMatch(skjc);
  if (match != null) return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  final single = RegExp(r'(\d+)节').firstMatch(skjc);
  if (single != null) {
    final s = int.parse(single.group(1)!);
    return (s, s);
  }
  return (1, 2);
}

/// 从 SKZC 字段解析周次
({String startWeek, String endWeek, bool? isOddWeek}) parseWeekInfo(String skzc) {
  final oddMatch = RegExp(r'(\d+)-(\d+)周\(单\)').firstMatch(skzc);
  if (oddMatch != null) {
    return (startWeek: oddMatch.group(1)!, endWeek: oddMatch.group(2)!, isOddWeek: true);
  }
  final evenMatch = RegExp(r'(\d+)-(\d+)周\(双\)').firstMatch(skzc);
  if (evenMatch != null) {
    return (startWeek: evenMatch.group(1)!, endWeek: evenMatch.group(2)!, isOddWeek: false);
  }
  final rangeMatch = RegExp(r'(\d+)-(\d+)周').firstMatch(skzc);
  if (rangeMatch != null) {
    return (startWeek: rangeMatch.group(1)!, endWeek: rangeMatch.group(2)!, isOddWeek: null);
  }
  final singleMatch = RegExp(r'(\d+)周').firstMatch(skzc);
  if (singleMatch != null) {
    return (startWeek: singleMatch.group(1)!, endWeek: singleMatch.group(1)!, isOddWeek: null);
  }
  return (startWeek: '1', endWeek: '16', isOddWeek: null);
}
