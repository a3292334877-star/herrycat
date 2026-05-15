import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// 深圳职业技术大学教务系统登录与课表抓取
/// 基于新版正方教务 v6+ Web表单认证
class SchoolLoginService {
  static const String _baseUrl = 'https://jwxt.szpu.edu.cn';
  static const String _loginPage = '/jwglxt/xtgl/login_slogin.html';
  static const String _pubKey = '/jwglxt/xtgl/login_getPublicKey.html';
  static const String _schedule = '/jwglxt/kbcx/xskbcx_cxXsKb.html';

  String _cookies = '';

  /// 登录
  Future<bool> login(String username, String password) async {
    final log = <String>[];

    // ── Step 1: 连通性检查 ──
    try {
      final r = await http.get(Uri.parse(_baseUrl)).timeout(const Duration(seconds: 4));
      log.add('✓ 可达(${r.statusCode})');
    } catch (e) {
      throw Exception('❌ 无法访问教务系统\n请确认已连接深职院Campus WiFi');
    }

    // ── Step 2: GET 登录页 → 拿 cookie + RSA 公钥 ──
    String modulus = '';
    String exponentHex = '10001';

    try {
      final r = await http.get(
        Uri.parse('$_baseUrl$_loginPage'),
        headers: _webHeaders,
      ).timeout(const Duration(seconds: 5));

      _cookies = _extractCookies(r);
      final html = r.body;

      if (_cookies.isNotEmpty) log.add('✓ cookie');

      // 从 HTML 提取 RSA 公钥
      for (final re in [
        RegExp(r"""var\s+modulus\s*=\s*['"]([^'"]+)['"]"""),
        RegExp(r"""modulus['"]\s*:\s*['"]([^'"]+)['"]"""),
        RegExp(r"""loginPublicKey\s*=\s*['"]([^'"]+)['"]"""),
      ]) {
        final m = re.firstMatch(html);
        if (m != null) { modulus = m.group(1)!; break; }
      }
      for (final re in [
        RegExp(r"""var\s+exponent\s*=\s*['"]([^'"]+)['"]"""),
        RegExp(r"""exponent['"]\s*:\s*['"]([^'"]+)['"]"""),
      ]) {
        final m = re.firstMatch(html);
        if (m != null) { exponentHex = m.group(1)!; break; }
      }
      log.add(modulus.isNotEmpty ? '✓ RSA(HTML)' : '⚠ RSA需API获取');
    } catch (e) {
      log.add('⚠ 登录页: $e');
    }

    // ── Step 2b: 如果HTML没提取到，走 API 获取 ──
    if (modulus.isEmpty) {
      try {
        final r = await http.get(
          Uri.parse('$_baseUrl$_pubKey'),
          headers: _cookieHeaders,
        ).timeout(const Duration(seconds: 4));
        final body = r.body.trim();
        if (body.startsWith('{')) {
          final d = jsonDecode(body);
          modulus = d['modulus'] ?? d['data']?['modulus'] ?? '';
          exponentHex = d['exponent'] ?? d['data']?['exponent'] ?? '10001';
          if (modulus.isNotEmpty) log.add('✓ RSA(API)');
        }
      } catch (_) {}
    }

    // ── Step 3: RSA 加密密码 ──
    String passwordEncoded;
    if (modulus.isNotEmpty) {
      try {
        passwordEncoded = _rsaEncrypt(password, modulus, exponentHex);
      } catch (_) {
        passwordEncoded = password;
      }
    } else {
      passwordEncoded = password;
    }

    // ── Step 4: POST 登录（Web表单格式） ──
    final loginUrl = '$_baseUrl$_loginPage';
    final bodies = [
      // 格式1: 新版正方标准字段
      'yhm=${Uri.encodeComponent(username)}&mm=${Uri.encodeComponent(passwordEncoded)}',
      // 格式2: 旧版字段名
      'userAccount=${Uri.encodeComponent(username)}&userPassword=${Uri.encodeComponent(passwordEncoded)}',
      // 格式3: JSON(某些配置)
      jsonEncode({'yhm': username, 'mm': passwordEncoded}),
      // 格式4: 明文
      'yhm=${Uri.encodeComponent(username)}&mm=${Uri.encodeComponent(password)}',
    ];

    String? lastErr;
    for (final body in bodies) {
      try {
        final isJson = body.startsWith('{');
        final r = await http.post(
          Uri.parse(loginUrl),
          headers: {
            ..._cookieHeaders,
            'Content-Type': isJson
                ? 'application/json; charset=UTF-8'
                : 'application/x-www-form-urlencoded; charset=UTF-8',
            'Referer': loginUrl,
          },
          body: body,
        ).timeout(const Duration(seconds: 6));

        final respBody = r.body.trim();
        final newCookies = _mergeCookies(_cookies, _extractCookies(r));

        // 登录成功 = 重定向到首页 或 JSON success
        if (r.statusCode == 302 ||
            (respBody.startsWith('{') && _isSuccess(respBody))) {
          _cookies = newCookies;
          log.add('✓ 登录成功');
          return true;
        }

        // 401/密码错误
        if (r.statusCode == 401 ||
            (respBody.startsWith('{') && respBody.contains('密码'))) {
          final msg = respBody.startsWith('{')
              ? (jsonDecode(respBody)['msg'] ?? '密码错误')
              : '密码错误';
          lastErr = msg;
          continue;
        }

        // 得到新cookie → 可能成功
        if (newCookies.isNotEmpty && newCookies != _cookies) {
          _cookies = newCookies;
          log.add('✓ 登录(cookie)');
          return true;
        }
      } catch (e) {
        lastErr = e.toString();
      }
    }

    if (lastErr != null) throw Exception(lastErr);
    throw Exception('登录失败\n${log.join('\n')}');
  }

  bool _isSuccess(String body) {
    try {
      final d = jsonDecode(body);
      return d['code'] == '0' || d['code'] == 0 || d['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ── 课表查询 ──
  Future<List<Map<String, dynamic>>> fetchSchedule() async {
    final log = <String>[];
    final now = DateTime.now();
    final year = now.year - (now.month < 9 ? 1 : 0);
    final xqm = (now.month >= 2 && now.month <= 7) ? '12' : '3';

    final bodies = [
      'xnm=$year&xqm=$xqm&kzlx=ck',
      'xnm=$year&xqm=$xqm',
      jsonEncode({'xnm': year.toString(), 'xqm': xqm}),
      jsonEncode({'XNXQDM': '$year-${year+1}-${xqm == "3" ? "1" : "2"}'}),
    ];

    for (final body in bodies) {
      final isJson = body.startsWith('{');
      try {
        final r = await http.post(
          Uri.parse('$_baseUrl$_schedule'),
          headers: {
            ..._cookieHeaders,
            'Content-Type': isJson
                ? 'application/json'
                : 'application/x-www-form-urlencoded',
            'Referer': '$_baseUrl/jwglxt/xtgl/index_initMenu.html',
          },
          body: body,
        ).timeout(const Duration(seconds: 8));

        final respBody = r.body.trim();
        if (respBody.isEmpty) { log.add('  → 空响应'); continue; }
        if (!respBody.startsWith('{')) {
          log.add('  → HTML(${respBody.length}b)');
          continue;
        }

        final data = jsonDecode(respBody);
        // 新版正方: { kbList: [...], ... }
        final rows = data['kbList'] ??
            data['datas']?['kbList'] ??
            data['datas']?['qxkccxx']?['rows'] ??
            data['rows'];
        if (rows is List && rows.isNotEmpty) {
          return rows.cast<Map<String, dynamic>>();
        }
        log.add('  → JSON无数据');
      } catch (e) {
        log.add('  → $e');
      }
    }

    throw Exception('获取课表失败\n${log.join('\n')}');
  }

  // ── Cookie ──
  String _extractCookies(http.Response resp) {
    final h = resp.headers['set-cookie'] ?? '';
    if (h.isEmpty) return '';
    final cs = <String>[];
    for (final p in h.split(',')) {
      final t = p.trim();
      final i = t.indexOf(';');
      final kv = i > 0 ? t.substring(0, i) : t;
      if (kv.contains('=')) cs.add(kv);
    }
    return cs.join('; ');
  }

  String _mergeCookies(String old, String add) =>
      add.isEmpty ? old : old.isEmpty ? add : '$old; $add';

  // ── RSA ──
  String _rsaEncrypt(String text, String modHex, String expHex) {
    final n = BigInt.parse(modHex, radix: 16);
    final e = BigInt.parse(expHex, radix: 16);
    final kl = (n.bitLength + 7) >> 3;
    final pl = kl - text.length - 3;
    if (pl < 8) return text;
    final rng = Random.secure();
    final ps = List<int>.generate(pl, (_) { int b; do { b = rng.nextInt(256); } while (b == 0); return b; });
    final em = [0x00, 0x02, ...ps, 0x00, ...utf8.encode(text)];
    final m = em.fold(BigInt.zero, (a, x) => (a << 8) + BigInt.from(x));
    BigInt r = BigInt.one, b = m, x = e;
    while (x > BigInt.zero) { if (x & BigInt.one == BigInt.one) r = (r * b) % n; b = (b * b) % n; x >>= 1; }
    final h = r.toRadixString(16);
    return h.length.isOdd ? '0$h' : h;
  }

  Map<String, String> get _webHeaders => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
  };

  Map<String, String> get _cookieHeaders => {
    ..._webHeaders,
    if (_cookies.isNotEmpty) 'Cookie': _cookies,
  };
}

/// 从 SKJC 字段解析节次
(int, int) parseSectionRange(String skjc) {
  final m = RegExp(r'(\d+)-(\d+)节').firstMatch(skjc);
  if (m != null) return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  final s = RegExp(r'(\d+)节').firstMatch(skjc);
  if (s != null) { final v = int.parse(s.group(1)!); return (v, v); }
  return (1, 2);
}

/// 从 SKZC 字段解析周次
({String startWeek, String endWeek, bool? isOddWeek}) parseWeekInfo(String skzc) {
  final om = RegExp(r'(\d+)-(\d+)周\(单\)').firstMatch(skzc);
  if (om != null) return (startWeek: om.group(1)!, endWeek: om.group(2)!, isOddWeek: true);
  final em = RegExp(r'(\d+)-(\d+)周\(双\)').firstMatch(skzc);
  if (em != null) return (startWeek: em.group(1)!, endWeek: em.group(2)!, isOddWeek: false);
  final rm = RegExp(r'(\d+)-(\d+)周').firstMatch(skzc);
  if (rm != null) return (startWeek: rm.group(1)!, endWeek: rm.group(2)!, isOddWeek: null);
  final sm = RegExp(r'(\d+)周').firstMatch(skzc);
  if (sm != null) return (startWeek: sm.group(1)!, endWeek: sm.group(1)!, isOddWeek: null);
  return (startWeek: '1', endWeek: '16', isOddWeek: null);
}
