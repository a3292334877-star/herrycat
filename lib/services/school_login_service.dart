import 'dart:convert';
import 'package:http/http.dart' as http;

/// 深圳职业技术大学教务系统登录与课表抓取服务
/// 使用移动端 API（无需 RSA 加密）
class SchoolLoginService {
  static const String _baseUrl = 'https://jwxt.szpu.edu.cn';

  String? _sessionId;

  /// 登录
  Future<bool> login(String username, String password) async {
    try {
      // 1. 获取 RSA 公钥（尝试多个可能的后缀）
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
          // 如果返回的是 HTML 而不是 JSON，说明路径不对
          if (body.startsWith('<') || !body.startsWith('{')) {
            continue;
          }

          final preData = jsonDecode(body);
          final keyData = preData['data'] ?? preData;
          modulus = keyData['modulus'] ?? keyData['key'] ?? '';
          exponentHex = keyData['exponent'] ?? '10001';
          break;
        } catch (_) {
          continue;
        }
      }

      // 2. RSA 加密密码（如果没拿到公钥则用明文）
      final encryptedPwd = modulus != null && modulus.isNotEmpty
          ? _rsaEncrypt(password, modulus, exponentHex)
          : base64Encode(utf8.encode(password));

      // 3. 登录请求（尝试多个登录接口）
      http.Response? loginResp;
      for (final loginPath in [
        '/jwapp/sys/emaphome/login.do',
        '/jwapp/sys/emaphome/login',
        '/jwapp/sys/login',
      ]) {
        try {
          final resp = await http.post(
            Uri.parse('$_baseUrl$loginPath'),
            headers: _headers,
            body: jsonEncode({
              'loginName': username,
              'password': encryptedPwd,
            }),
          ).timeout(const Duration(seconds: 15));

          final body = resp.body.trim();
          // 跳过 HTML 响应
          if (body.startsWith('<') || !body.startsWith('{')) {
            continue;
          }

          loginResp = resp;
          break;
        } catch (_) {
          continue;
        }
      }

      if (loginResp == null) {
        throw Exception('无法连接教务系统服务器，请确认网络已连接校园WiFi或使用VPN');
      }

      final body = loginResp.body.trim();
      final loginData = jsonDecode(body);
      final success = (loginData['code'] == '0' || loginData['code'] == 0 ||
                      loginData['success'] == true || loginData['success'] == 'true');

      if (!success) {
        final msg = loginData['msg'] ?? loginData['message'] ?? loginData['error'] ?? '账号或密码错误';
        throw Exception(msg);
      }

      // 4. 提取 session
      final cookieHeader = loginResp.headers['set-cookie'] ?? '';
      final jsessionMatch = RegExp(r'JSESSIONID=([^;]+)').firstMatch(cookieHeader);
      _sessionId = jsessionMatch?.group(1) ??
                  loginData['data']?['token'] ??
                  loginData['token'] ??
                  loginData['sessionid'] ??
                  '';

      return true;
    } on http.ClientException catch (e) {
      if (e.message.contains('SocketException') || e.message.contains('DNS')) {
        throw Exception('网络无法访问教务系统，请确认已连接校园WiFi（深职院Campus网）或使用VPN');
      }
      rethrow;
    }
  }

  /// RSA 加密（PKCS1v15）
  String _rsaEncrypt(String plaintext, String modulusHex, String exponentHex) {
    try {
      if (modulusHex.isEmpty) {
        // 没有公钥，直接 base64（某些系统兼容）
        return base64Encode(utf8.encode(plaintext));
      }

      final n = BigInt.parse(modulusHex, radix: 16);
      final e = BigInt.parse(exponentHex, radix: 16);
      final keyByteLen = (n.bitLength + 7) >> 3;

      // EM = 0x00 || 0x02 || PS || 0x00 || T
      final psLen = keyByteLen - plaintext.length - 3;
      if (psLen < 8) throw Exception('Password too long for RSA key size');

      final ps = List<int>.generate(psLen, (i) => _pseudoRandomByte(i));
      final t = utf8.encode(plaintext);
      final em = [0x00, 0x02, ...ps, 0x00, ...t];

      final m = _bytesToBigInt(em);
      final c = _modexp(m, e, n);
      return _bigIntToHex(c);
    } catch (_) {
      return base64Encode(utf8.encode(plaintext));
    }
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

  int _pseudoRandomByte(int seed) {
    // 确定性伪随机（不依赖 Random 类）
    return ((seed * 0x15A4E35 + 1) % 256).abs();
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Content-Type': 'application/json; charset=UTF-8',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148',
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

    http.Response? resp;
    for (final schedulePath in [
      '/jwapp/sys/kcbcxmdl/modules/qxkcp/qxkccxx.do',
      '/jwapp/sys/kcbcxmdl/modules/qxkcp/qxkccxx',
      '/jwapp/sys/kcbcxmdl/modules/qxkcp/queryKccxx',
      '/jwapp/sys/kcbcxmdl/modules/qxkccxx/qxkccxx.do',
    ]) {
      try {
        final r = await http.post(
          Uri.parse('$_baseUrl$schedulePath'),
          headers: {
            ..._headers,
            'Cookie': 'JSESSIONID=$_sessionId',
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
        if (body.startsWith('<') || !body.startsWith('{')) continue;

        resp = r;
        break;
      } catch (_) {
        continue;
      }
    }

    if (resp == null) {
      throw Exception('无法获取课表，请确认账号密码正确且网络正常');
    }

    if (resp.statusCode != 200) {
      throw Exception('获取课表失败，HTTP ${resp.statusCode}，请尝试重新登录');
    }

    final data = jsonDecode(resp.body);
    final success = data['code'] == '0' || data['code'] == 0 ||
                    data['success'] == true || data['success'] == 'true';
    if (!success) {
      final msg = data['msg'] ?? data['message'] ?? '获取课表失败，可能会话已过期，请重新登录';
      throw Exception(msg);
    }

    final rows = data['datas']?['qxkccxx']?['rows'] ??
                 data['data']?['rows'] ??
                 data['datas']?['rows'];
    if (rows == null) return [];
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// 获取当前学期代码
  Future<String> _getCurrentTerm() async {
    for (final termPath in [
      '/jwapp/sys/emaphome/getQXQDMCurrent.do',
      '/jwapp/sys/emaphome/getQXQ DMCurrent',
      '/jwapp/sys/emaphome/getCurrentTerm',
    ]) {
      try {
        final resp = await http.get(
          Uri.parse('$_baseUrl$termPath'),
          headers: {..._headers, 'Cookie': 'JSESSIONID=$_sessionId'},
        ).timeout(const Duration(seconds: 10));
        final body = resp.body.trim();
        if (!body.startsWith('{')) continue;
        final data = jsonDecode(body);
        return data['data']?['QXXQDM'] ?? data['QXXQDM'] ?? '2025-2026-2';
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
      endWeek: singleMatch.group(1)!,
      isOddWeek: null,
    );
  }

  return (startWeek: '1', endWeek: '16', isOddWeek: null);
}
