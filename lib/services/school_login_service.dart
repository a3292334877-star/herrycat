import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// 深圳职业技术大学教务系统登录与课表抓取服务
class SchoolLoginService {
  static const String _baseUrl = 'https://jwxt.szpu.edu.cn';

  String? _sessionId;
  String _cookies = '';

  /// 登录（改进版：详细错误追踪 + 多策略重试）
  Future<bool> login(String username, String password) async {
    final errors = <String>[];

    // 0. 连通性检查
    try {
      await http.get(Uri.parse(_baseUrl)).timeout(const Duration(seconds: 5));
    } on http.ClientException catch (e) {
      if (e.message.contains('SocketException') ||
          e.message.contains('DNS') ||
          e.message.contains('Connection refused')) {
        throw Exception('无法访问教务系统服务器\n'
            '请确认：\n'
            '1. 已连接校园WiFi（深职院Campus网）\n'
            '2. 或已启用深职院VPN');
      }
      errors.add('连通性检查: ${e.message}');
    } catch (e) {
      errors.add('连通性检查: $e');
    }

    // 1. 尝试获取 RSA 公钥
    String? modulus;
    String exponentHex = '10001';

    for (final keyPath in [
      '/jwapp/sys/emaphome/getRSAKey.do',
      '/jwapp/sys/emaphome/getRSAKey',
      '/jwapp/sys/login/getRSAKey',
    ]) {
      try {
        final preResp = await http.get(
          Uri.parse('$_baseUrl$keyPath'),
          headers: _headers,
        ).timeout(const Duration(seconds: 10));

        final body = preResp.body.trim();
        if (body.isEmpty) continue;
        if (body.startsWith('<') || !body.startsWith('{')) continue;

        final preData = jsonDecode(body);
        final keyData = preData['data'] ?? preData;
        modulus = keyData['modulus'] ?? keyData['key'] ?? keyData['publicKey'] ?? '';
        exponentHex = keyData['exponent'] ?? '10001';

        if (modulus != null && modulus.isNotEmpty) break;
      } catch (e) {
        // 单个路径失败不致命
      }
    }

    // 2. 加密密码
    String? encryptedPwd;
    if (modulus != null && modulus.isNotEmpty) {
      try {
        encryptedPwd = _rsaEncrypt(password, modulus, exponentHex);
      } catch (e) {
        errors.add('RSA加密失败: $e，将尝试其他方式');
      }
    }

    // 3. 登录 — 多策略重试
    final loginPaths = [
      '/jwapp/sys/emaphome/login.do',
      '/jwapp/sys/emaphome/login',
      '/jwapp/sys/login',
      '/jwapp/sys/emaphome/login.do?method=login',
    ];

    // 策略 A: JSON body + RSA加密密码
    if (encryptedPwd != null) {
      for (final path in loginPaths) {
        try {
          final resp = await http.post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers,
            body: jsonEncode({
              'loginName': username,
              'password': encryptedPwd,
            }),
          ).timeout(const Duration(seconds: 15));

          final cookies = _extractCookies(resp);
          final body = resp.body.trim();

          if (_isLoginSuccess(resp, body)) {
            _sessionId = _extractSessionId(resp, body);
            _cookies = cookies;
            return true;
          }

          if (body.isNotEmpty && body.startsWith('{')) {
            final data = jsonDecode(body);
            final msg = data['msg'] ?? data['message'] ?? data['error'] ?? '';
            if (msg.isNotEmpty) errors.add('$path → $msg');
          }
        } catch (_) {}
      }
    }

    // 策略 B: JSON body + 明文密码
    for (final path in loginPaths) {
      try {
        final resp = await http.post(
          Uri.parse('$_baseUrl$path'),
          headers: _headers,
          body: jsonEncode({
            'loginName': username,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 15));

        final cookies = _extractCookies(resp);
        final body = resp.body.trim();

        if (_isLoginSuccess(resp, body)) {
          _sessionId = _extractSessionId(resp, body);
          _cookies = cookies;
          return true;
        }

        if (body.isNotEmpty && body.startsWith('{')) {
          final data = jsonDecode(body);
          final msg = data['msg'] ?? data['message'] ?? data['error'] ?? '';
          if (msg.isNotEmpty) errors.add('$path(明文) → $msg');
        }
      } catch (_) {}
    }

    // 策略 C: form-urlencoded body（某些旧版教务系统）
    for (final path in loginPaths) {
      try {
        final resp = await http.post(
          Uri.parse('$_baseUrl$path'),
          headers: {
            ..._headers,
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          },
          body: 'loginName=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}',
        ).timeout(const Duration(seconds: 15));

        final cookies = _extractCookies(resp);
        final body = resp.body.trim();

        if (_isLoginSuccess(resp, body)) {
          _sessionId = _extractSessionId(resp, body);
          _cookies = cookies;
          return true;
        }

        if (body.isNotEmpty && body.startsWith('{')) {
          final data = jsonDecode(body);
          final msg = data['msg'] ?? data['message'] ?? data['error'] ?? '';
          if (msg.isNotEmpty) errors.add('$path(form) → $msg');
        }
      } catch (_) {}
    }

    // 所有策略都失败了
    final errorDetail = errors.isNotEmpty
        ? '详细信息:\n${errors.take(3).map((e) => '  • $e').join('\n')}'
        : '服务器无响应，请确认账号密码正确且网络为校园网';
    throw Exception(errorDetail);
  }

  /// 判断登录是否成功
  bool _isLoginSuccess(http.Response resp, String body) {
    if (body.isEmpty) return false;
    if (body.startsWith('<')) return false; // HTML 响应 = 失败

    if (body.startsWith('{')) {
      try {
        final data = jsonDecode(body);
        return data['code'] == '0' ||
            data['code'] == 0 ||
            data['success'] == true ||
            data['success'] == 'true' ||
            (data['result'] != null && data['result'] != 'error');
      } catch (_) {
        return false;
      }
    }

    // 302 重定向通常表示登录成功
    if (resp.statusCode == 302) return true;

    return false;
  }

  /// 提取所有 Cookie
  String _extractCookies(http.Response resp) {
    final cookieHeader = resp.headers['set-cookie'] ?? '';
    if (cookieHeader.isEmpty) return '';

    // 提取所有 cookie 键值对
    final cookies = <String>[];
    for (final part in cookieHeader.split(',')) {
      final trimmed = part.trim();
      final semiIdx = trimmed.indexOf(';');
      final kv = semiIdx > 0 ? trimmed.substring(0, semiIdx) : trimmed;
      if (kv.contains('=')) cookies.add(kv);
    }
    return cookies.join('; ');
  }

  /// 提取 Session ID
  String _extractSessionId(http.Response resp, String body) {
    // 从 Set-Cookie 提取
    final cookieHeader = resp.headers['set-cookie'] ?? '';
    final jsessionMatch = RegExp(r'JSESSIONID=([^;]+)').firstMatch(cookieHeader);
    if (jsessionMatch != null) return jsessionMatch.group(1)!;

    // 从响应 body 提取
    if (body.startsWith('{')) {
      try {
        final data = jsonDecode(body);
        return data['data']?['token'] ??
            data['token'] ??
            data['sessionid'] ??
            data['data']?['sessionId'] ??
            '';
      } catch (_) {}
    }

    return '';
  }

  /// RSA 加密（PKCS1v15，使用真随机填充）
  String _rsaEncrypt(String plaintext, String modulusHex, String exponentHex) {
    final n = BigInt.parse(modulusHex, radix: 16);
    final e = BigInt.parse(exponentHex, radix: 16);
    final keyByteLen = (n.bitLength + 7) >> 3;

    // EM = 0x00 || 0x02 || PS || 0x00 || T
    final psLen = keyByteLen - plaintext.length - 3;
    if (psLen < 8) throw Exception('密码过长，RSA密钥不足');

    // 使用真随机填充（PKCS1 v1.5 规范要求非零随机字节）
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
    if (_sessionId == null || _sessionId!.isEmpty) {
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
      throw Exception('获取课表失败，HTTP ${resp.statusCode}，请尝试重新登录');
    }

    final data = jsonDecode(resp.body);
    // 教务系统有时用 code/success，有时直接返回数据
    final code = data['code'];
    final success = code == '0' || code == 0 ||
        data['success'] == true || data['success'] == 'true';

    if (!success && code != null) {
      final msg = data['msg'] ?? data['message'] ?? '获取课表失败，可能会话已过期，请重新登录';
      throw Exception(msg);
    }

    // 尝试多种数据路径
    final rows = data['datas']?['qxkccxx']?['rows'] ??
        data['data']?['rows'] ??
        data['datas']?['rows'] ??
        data['rows'];

    if (rows == null) return [];
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// 获取当前学期代码
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
            data['QXXQDM'] ??
            '';
        if (term.isNotEmpty) return term;
      } catch (_) {
        continue;
      }
    }
    return '2025-2026-2';
  }
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
    return (
      startWeek: singleMatch.group(1)!,
      endWeek: singleMatch.group(2)!,
      isOddWeek: null,
    );
  }

  return (startWeek: '1', endWeek: '16', isOddWeek: null);
}
