import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// 深圳职业技术大学教务系统登录与课表抓取服务
class SchoolLoginService {
  static const String _baseUrl = 'https://jwxt.szpu.edu.cn';

  String _cookies = '';

  /// 登录（快速超时 + 详细日志）
  Future<bool> login(String username, String password) async {
    final log = <String>[];

    // ── 0. 连通性检查 (3s) ──
    try {
      final connResp = await http
          .get(Uri.parse(_baseUrl))
          .timeout(const Duration(seconds: 3));
      log.add('✓ 可达 (HTTP ${connResp.statusCode})');
    } on http.ClientException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('socke') || msg.contains('dns') || msg.contains('refused')) {
        throw Exception('❌ 无法访问教务系统\n\n请确认手机已连接深职院Campus WiFi或VPN');
      }
      log.add('⚠ 连通: ${e.message}');
    } catch (e) {
      log.add('⚠ 连通超时: $e');
    }

    // ── 0.5 初始 Session (5s max) ──
    await _getInitialSession(log);

    // ── 1. RSA 公钥 (5s max) ──
    String? modulus;
    String exponentHex = '10001';

    for (final keyPath in [
      '/jwglxt/xtgl/login_getPublicKey.html',
      '/jwglxt/xtgl/login/login_getPublicKey.html',
      '/jwapp/sys/emaphome/getRSAKey.do',
      '/jwapp/sys/emaphome/getRSAKey',
    ]) {
      try {
        final preResp = await http
            .get(Uri.parse('$_baseUrl$keyPath'), headers: _headerWithCookie)
            .timeout(const Duration(seconds: 4));

        final body = preResp.body.trim();
        if (body.isEmpty) continue;
        if (body.startsWith('{')) {
          final data = jsonDecode(body);
          modulus = data['modulus'] ?? data['data']?['modulus'] ?? '';
          exponentHex = data['exponent'] ?? data['data']?['exponent'] ?? '10001';
          if (modulus != null && modulus.isNotEmpty) {
            log.add('✓ RSA公钥 ($keyPath)');
            break;
          }
        }
      } catch (_) {}
    }

    // 从 HTML 提取
    if (modulus == null || modulus.isEmpty) {
      try {
        final pageResp = await http
            .get(Uri.parse('$_baseUrl/jwglxt/xtgl/login_slogin.html'), headers: _headerWithCookie)
            .timeout(const Duration(seconds: 4));
        final html = pageResp.body;
        final modMatch =
            RegExp(r"modulus\s*=\s*'([^']+)'").firstMatch(html) ??
            RegExp(r'modulus\s*=\s*"([^"]+)"').firstMatch(html);
        final expMatch =
            RegExp(r"exponent\s*=\s*'([^']+)'").firstMatch(html) ??
            RegExp(r'exponent\s*=\s*"([^"]+)"').firstMatch(html);
        if (modMatch != null) {
          modulus = modMatch.group(1)!;
          if (expMatch != null) exponentHex = expMatch.group(1)!;
          log.add('✓ RSA(HTML提取)');
        }
      } catch (_) {}
    }
    if (modulus == null || modulus.isEmpty) log.add('⚠ 无RSA公钥');

    // ── 2. 加密 ──
    String? encryptedPwd;
    if (modulus != null && modulus.isNotEmpty) {
      try {
        encryptedPwd = _rsaEncrypt(password, modulus, exponentHex);
      } catch (_) {}
    }

    // ── 3. 登录 (每条路径5s) ──
    final loginPaths = [
      '/jwglxt/xtgl/login_slogin.html',
      '/jwapp/sys/emaphome/login.do',
      '/jwapp/sys/emaphome/login',
    ];

    // 策略A: RSA加密 JSON
    if (encryptedPwd != null) {
      for (final path in loginPaths) {
        final r = await _tryLogin(path, username, encryptedPwd, log);
        if (r != null) { _cookies = r; return true; }
      }
    }

    // 策略B: 明文 JSON
    for (final path in loginPaths) {
      final r = await _tryLogin(path, username, password, log);
      if (r != null) { _cookies = r; return true; }
    }

    // 策略C: form body (仅旧版路径)
    for (final path in ['/jwapp/sys/emaphome/login.do', '/jwapp/sys/emaphome/login']) {
      final r = await _tryLoginForm(path, username, password, log);
      if (r != null) { _cookies = r; return true; }
    }

    throw Exception('登录失败\n\n${log.join('\n')}');
  }

  Future<void> _getInitialSession(List<String> log) async {
    for (final path in ['/', '/jwglxt/xtgl/login_slogin.html', '/jwapp/sys/emaphome/login.do']) {
      try {
        final resp = await http
            .get(Uri.parse('$_baseUrl$path'), headers: _headers)
            .timeout(const Duration(seconds: 3));
        final c = _extractCookies(resp);
        if (c.isNotEmpty) { _cookies = c; log.add('✓ cookie($path)'); return; }
      } catch (_) {}
    }
  }

  Future<String?> _tryLogin(
      String path, String username, String password, List<String> log) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: _headerWithCookie,
        body: jsonEncode({'loginName': username, 'password': password}),
      ).timeout(const Duration(seconds: 5));

      final body = resp.body.trim();
      final cookies = _mergeCookies(_cookies, _extractCookies(resp));

      // JSON 响应
      if (body.startsWith('{')) {
        final data = jsonDecode(body);
        final ok = data['code'] == '0' || data['code'] == 0 ||
            data['success'] == true || data['success'] == 'true';
        if (ok) { log.add('✓ 登录成功 ($path)'); return cookies; }
        final msg = data['msg'] ?? data['message'] ?? '';
        if (msg.isNotEmpty) log.add('  $path → $msg');
        return null;
      }

      // 302 重定向
      if (resp.statusCode == 302) {
        log.add('✓ 登录(302 $path)');
        return cookies;
      }

      // 401/404
      if (resp.statusCode == 401) { log.add('  $path → 401'); return null; }
      if (resp.statusCode == 404) { log.add('  $path → 404'); return null; }

      // HTML — 可能登录成功（重定向到首页）
      if (cookies.isNotEmpty && cookies != _cookies) {
        log.add('✓ 登录($path HTML+cookie)');
        return cookies;
      }

      log.add('  $path → HTTP ${resp.statusCode}');
    } catch (e) {
      log.add('  $path → $e');
    }
    return null;
  }

  Future<String?> _tryLoginForm(
      String path, String username, String password, List<String> log) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl$path'),
        headers: {
          ..._headerWithCookie,
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: 'loginName=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}',
      ).timeout(const Duration(seconds: 5));
      final cookies = _mergeCookies(_cookies, _extractCookies(resp));
      if (cookies.isNotEmpty && cookies != _cookies) { log.add('✓ 登录(form $path)'); return cookies; }
      log.add('  form $path → HTTP ${resp.statusCode}');
    } catch (e) {
      log.add('  form $path → $e');
    }
    return null;
  }

  // ── Cookie 工具 ──

  String _extractCookies(http.Response resp) {
    final h = resp.headers['set-cookie'] ?? '';
    if (h.isEmpty) return '';
    final cookies = <String>[];
    for (final p in h.split(',')) {
      final t = p.trim();
      final i = t.indexOf(';');
      final kv = i > 0 ? t.substring(0, i) : t;
      if (kv.contains('=')) cookies.add(kv);
    }
    return cookies.join('; ');
  }

  String _mergeCookies(String old, String add) =>
      add.isEmpty ? old : old.isEmpty ? add : '$old; $add';

  // ── RSA ──

  String _rsaEncrypt(String plaintext, String modulusHex, String exponentHex) {
    final n = BigInt.parse(modulusHex, radix: 16);
    final e = BigInt.parse(exponentHex, radix: 16);
    final kb = (n.bitLength + 7) >> 3;
    final pl = kb - plaintext.length - 3;
    if (pl < 8) throw Exception('密码过长');
    final rng = Random.secure();
    final ps = List<int>.generate(pl, (_) { int b; do { b = rng.nextInt(256); } while (b == 0); return b; });
    final t = utf8.encode(plaintext);
    final em = [0x00, 0x02, ...ps, 0x00, ...t];
    final m = _bytesToBigInt(em);
    final c = _modexp(m, e, n);
    return _bigIntToHex(c);
  }

  BigInt _bytesToBigInt(List<int> b) => b.fold(BigInt.zero, (a, x) => (a << 8) + BigInt.from(x));
  String _bigIntToHex(BigInt v) { final h = v.toRadixString(16); return h.length.isOdd ? '0$h' : h; }
  BigInt _modexp(BigInt base, BigInt exp, BigInt mod) {
    BigInt r = BigInt.one, b = base, e = exp;
    while (e > BigInt.zero) { if (e & BigInt.one == BigInt.one) r = (r * b) % mod; b = (b * b) % mod; e >>= 1; }
    return r;
  }

  // ── Headers ──

  Map<String, String> get _headers => {
    'Accept': 'text/html,application/json;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    'Origin': _baseUrl,
    'Referer': '$_baseUrl/jwglxt/xtgl/login_slogin.html',
  };

  Map<String, String> get _headerWithCookie => {
    ..._headers,
    if (_cookies.isNotEmpty) 'Cookie': _cookies,
  };

  // ── 课表 ──

  Future<List<Map<String, dynamic>>> fetchSchedule() async {
    final termCode = await _getCurrentTerm();
    final errors = <String>[];

    http.Response? resp;
    for (final path in [
      '/jwapp/sys/kcbcxmdl/modules/qxkcp/qxkccxx.do',
      '/jwapp/sys/kcbcxmdl/modules/qxkcp/qxkccxx',
      '/jwapp/sys/kcbcxmdl/modules/qxkcp/queryKccxx',
      '/jwapp/sys/kcbcxmdl/modules/qxkccxx/qxkccxx.do',
      '/jwapp/sys/kcbcxmdl/modules/qxkcb/qxkccxx.do',
      '/jwglxt/kbcx/xskbcx_cxXsKb.html',
    ]) {
      try {
        http.Response r;
        if (path.contains('jwglxt')) {
          r = await http.post(
            Uri.parse('$_baseUrl$path'),
            headers: _headerWithCookie,
            body: 'xnm=${termCode.substring(0, 4)}&xqm=${_termToXqm(termCode)}&kzlx=ck',
          ).timeout(const Duration(seconds: 10));
        } else {
          r = await http.post(
            Uri.parse('$_baseUrl$path'),
            headers: _headerWithCookie,
            body: jsonEncode({
              'XNXQDM': termCode,
              '*json': '1',
              'querySetting': jsonEncode([
                {'name': 'XNXQDM', 'value': termCode, 'linkOpt': 'and', 'builder': 'equal'},
              ]),
              '*order': '+KCH,+KXH,-SKZC,+SKXQ,+SKJC',
            }),
          ).timeout(const Duration(seconds: 10));
        }

        final body = r.body.trim();
        if (body.isEmpty) continue;
        if (!body.startsWith('{')) continue;
        resp = r;
        break;
      } catch (e) {
        errors.add('$path: $e');
      }
    }

    if (resp == null) {
      final d = errors.isNotEmpty ? '\n${errors.take(3).join('\n')}' : '';
      throw Exception('获取课表失败，会话可能已过期$d');
    }

    final data = jsonDecode(resp.body);
    final code = data['code'];
    if (code != null && code != '0' && code != 0 && data['success'] != true) {
      throw Exception(data['msg'] ?? data['message'] ?? '获取课表失败');
    }

    final rows = data['datas']?['qxkccxx']?['rows'] ??
        data['data']?['rows'] ?? data['datas']?['rows'] ?? data['rows'];
    if (rows is List) return rows.cast<Map<String, dynamic>>();
    return [];
  }

  String _termToXqm(String tc) {
    final p = tc.split('-');
    if (p.length >= 3) {
      switch (p[2]) { case '1': return '3'; case '2': return '12'; }
    }
    return '12';
  }

  Future<String> _getCurrentTerm() async {
    for (final p in [
      '/jwapp/sys/emaphome/getQXQDMCurrent.do',
      '/jwapp/sys/emaphome/getCurrentTerm',
    ]) {
      try {
        final r = await http.get(Uri.parse('$_baseUrl$p'), headers: _headerWithCookie)
            .timeout(const Duration(seconds: 5));
        final b = r.body.trim();
        if (!b.startsWith('{')) continue;
        final d = jsonDecode(b);
        final t = d['data']?['QXXQDM'] ?? d['QXXQDM'] ?? '';
        if (t.isNotEmpty) return t;
      } catch (_) {}
    }
    return '2025-2026-2';
  }
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
