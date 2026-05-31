import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/course_provider.dart';
import '../models/course_model.dart';
import 'package:provider/provider.dart';

class ImportScheduleScreen extends StatefulWidget {
  const ImportScheduleScreen({super.key});

  @override
  State<ImportScheduleScreen> createState() => _ImportScheduleScreenState();
}

class _ImportScheduleScreenState extends State<ImportScheduleScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String _status = '请登录教务系统，进入课表页面';
  bool _captured = false;
  final List<String> _logs = [];
  final ScrollController _logScrollCtrl = ScrollController();

  static const _hookScript = '''
(function() {
  if (window.__hooked) return;
  window.__hooked = true;
  window.__scheduleData = window.__scheduleData || [];

  function isSchool(url) {
    return url.indexOf('szpu.edu.cn') !== -1;
  }

  var _fetch = window.fetch;
  window.fetch = function(url, opts) {
    var urlStr = typeof url === 'string' ? url : (url && url.url || '');
    if (!isSchool(urlStr)) return _fetch.apply(this, arguments);
    return _fetch.apply(this, arguments).then(function(r) {
      var c = r.clone();
      c.text().then(function(b) {
        if (b.indexOf('kbList') > 0 || b.indexOf('kcmc') > 0) {
          window.__scheduleData.push(b);
          hLog.postMessage('HOOKED:' + b.length);
        }
      });
      return r;
    });
  };

  var _open = XMLHttpRequest.prototype.open;
  var _send = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function() {
    this._hxUrl = arguments[1] || '';
    return _open.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    var self = this;
    if (!isSchool(self._hxUrl || '')) return _send.apply(this, arguments);
    this.addEventListener('loadend', function() {
      if (self.readyState === 4 && self.responseText) {
        var txt = self.responseText;
        if (txt.indexOf('kbList') > 0 || txt.indexOf('kcmc') > 0) {
          window.__scheduleData.push(txt);
          hLog.postMessage('HOOKED:' + txt.length);
        }
      }
    });
    return _send.apply(this, arguments);
  };
})();
''';

  static const _scanScript = '''
(function() {
  var output = {intercepted: window.__scheduleData || []};

  // 扫描 sessionStorage / localStorage
  for (var i = 0; i < sessionStorage.length; i++) {
    var k = sessionStorage.key(i);
    var v = sessionStorage.getItem(k);
    if (v && v.length < 100000) output['ss_' + k] = v;
  }
  for (var i = 0; i < localStorage.length; i++) {
    var k = localStorage.key(i);
    var v = localStorage.getItem(k);
    if (v && v.length < 100000) output['ls_' + k] = v;
  }

  // 提取所有表格的结构化数据
  var tables = document.querySelectorAll('table');
  var allTables = [];
  for (var ti = 0; ti < tables.length; ti++) {
    var table = tables[ti];
    var rows = [];
    var trs = table.querySelectorAll('tr');
    for (var r = 0; r < trs.length; r++) {
      var row = [];
      var cells = trs[r].querySelectorAll('td, th');
      for (var c = 0; c < cells.length; c++) {
        row.push({
          t: (cells[c].innerText || cells[c].textContent || '').trim(),
          cs: parseInt(cells[c].getAttribute('colspan') || '1'),
          rs: parseInt(cells[c].getAttribute('rowspan') || '1')
        });
      }
      if (row.length > 0) rows.push(row);
    }
    if (rows.length > 1) {
      allTables.push({rows: rows, cols: rows[0].length});
    }
  }
  output['_tables'] = allTables;

  // 页面文本
  output['_bodyText'] = (document.body ? document.body.innerText : '').substring(0, 2000);
  output['_url'] = location.href;
  output['_title'] = document.title;
  output['_tableCount'] = tables.length;

  // iframe 文本
  var iframes = document.querySelectorAll('iframe');
  for (var i = 0; i < iframes.length; i++) {
    try {
      var doc = iframes[i].contentDocument || iframes[i].contentWindow.document;
      if (doc) output['_iframe'+i] = doc.body.innerText.substring(0, 500);
    } catch(e) {}
  }

  hLog.postMessage(JSON.stringify(output));
})();
''';

  @override
  void dispose() {
    _logScrollCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _loading = true);
            _log('→ ${url.length > 80 ? url.substring(0, 80) : url}');
          },
          onPageFinished: (url) {
            setState(() => _loading = false);
            _log('页面加载完成');
            _injectHooks();
          },
        ),
      )
      ..addJavaScriptChannel('hLog', onMessageReceived: (msg) {
        final m = msg.message;
        if (m.startsWith('HOOKED:')) {
          _log('钩子截获: ${m.substring(7)} 字节');
          return;
        }
        _log('收到数据: ${m.length > 200 ? '${m.substring(0, 200)}...' : m}');
        _processResult(m);
      })
      ..loadRequest(Uri.parse(
          'https://authserver.szpu.edu.cn/authserver/login'
          '?service=https%3A%2F%2Fjwxt.szpu.edu.cn%2Fjwglxt%2Fxtgl%2Flogin_slogin.html'));
  }

  void _injectHooks() {
    _controller.runJavaScript(_hookScript).catchError((_) {});
  }

  void _log(String s) {
    setState(() {
      _logs.add(
          '[${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}] $s');
      if (_logs.length > 30) _logs.removeAt(0);
    });
    if (_logScrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _logScrollCtrl.animateTo(_logScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      });
    }
  }

  Future<void> _grabSchedule() async {
    if (_captured) return;
    _log('开始扫描...');

    try {
      final url = await _controller.currentUrl() ?? '';
      _log('当前URL: ${url.length > 80 ? url.substring(0, 80) : url}');

      await _controller.runJavaScript(_hookScript);
      await Future.delayed(const Duration(milliseconds: 300));
      await _controller.runJavaScript(_scanScript);

      await Future.delayed(const Duration(seconds: 1));

      if (!_captured && mounted) {
        setState(() => _status = '未识别到课表数据，请确保已进入课表页面');
      }
    } catch (e) {
      _log('出错: $e');
    }
  }

  void _processResult(String result) {
    if (_captured) return;
    try {
      final data = jsonDecode(result);

      if (data is! Map) return;

      // 1. 钩子截获的 API 数据
      final intercepted = data['intercepted'];
      if (intercepted is List && intercepted.isNotEmpty) {
        _log('钩子截获 ${intercepted.length} 条API响应');
        for (final item in intercepted) {
          if (item is String && (item.contains('kbList') || item.contains('kcmc'))) {
            _tryImportJson(item);
            return;
          }
        }
      }

      // 2. 结构化表格数据（服务端渲染的 HTML 课表）
      final tables = data['_tables'];
      if (tables is List && tables.isNotEmpty) {
        _log('找到 ${tables.length} 个表格');
        for (final t in tables) {
          if (t is Map && t['rows'] is List) {
            final courses = _parseHtmlTable(t['rows'] as List);
            if (courses.isNotEmpty) {
              _importCourses(courses);
              return;
            }
          }
        }
      }

      // 3. sessionStorage / localStorage 中的 JSON
      if (data['_bodyText'] != null) {
        _log('扫描完成: title=${data['_title']}, tables=${data['_tableCount']}, bodyLen=${(data['_bodyText'] as String).length}');

        for (final key in data.keys) {
          if (key.startsWith('_')) continue;
          if (key == 'intercepted') continue;
          final val = data[key];
          if (val is String &&
              (val.contains('kbList') || val.contains('kcmc'))) {
            _log('找到数据: $key, len=${val.length}');
            _tryImportJson(val);
            return;
          }
        }

        final body = data['_bodyText'] as String;
        _log('bodyText预览: ${body.length > 200 ? body.substring(0, 200) : body}');

        if (!_captured && mounted) {
          setState(() => _status = '未识别到课表数据，请确保已进入课表页面');
        }
        return;
      }

      // 4. 直接的 API JSON 响应
      if (data['kbList'] != null || data['rows'] != null) {
        _log('识别到API响应');
        _tryImportJson(result);
      }
    } catch (e) {
      _log('解析异常: $e');
      _tryImportJson(result);
    }
  }

  // ─── HTML 表格解析 ───

  List<Course> _parseHtmlTable(List rows) {
    if (rows.isEmpty) return [];
    final courses = <Course>[];

    // 将 rows 转为 List<List<Map>>
    final table = <List<Map<String, dynamic>>>[];
    for (final r in rows) {
      if (r is! List) continue;
      final row = <Map<String, dynamic>>[];
      for (final c in r) {
        if (c is Map) {
          row.add({
            't': c['t']?.toString() ?? '',
            'cs': (c['cs'] as num?)?.toInt() ?? 1,
            'rs': (c['rs'] as num?)?.toInt() ?? 1,
          });
        }
      }
      if (row.isNotEmpty) table.add(row);
    }
    if (table.isEmpty) return [];

    // 找表头行 → 建立 列→星期几 的映射
    int headerRow = -1;
    final dayMap = <int, int>{};
    const dayChars = ['一', '二', '三', '四', '五', '六', '日'];

    for (var r = 0; r < table.length; r++) {
      for (var c = 0; c < table[r].length; c++) {
        final text = table[r][c]['t'] as String;
        for (var d = 0; d < dayChars.length; d++) {
          if (text.contains('周$dayChars[d]') || text.contains('星期$dayChars[d]')) {
            dayMap[c] = d + 1; // 1=周一 ... 7=周日
            headerRow = r;
          }
        }
      }
      if (dayMap.isNotEmpty) break;
    }

    if (dayMap.isEmpty) {
      // 无星期表头，尝试按列数推断
      final cols = table.isNotEmpty ? table[0].length : 0;
      if (cols >= 6 && cols <= 8) {
        for (var c = 1; c < cols && c <= 7; c++) {
          dayMap[c] = c;
        }
        headerRow = 0;
      } else {
        return [];
      }
    }

    _log('解析HTML课表: ${table.length}行, 星期列=$dayMap');

    // 建立 rowspan 占用追踪
    final occupied = <int, Map<int, bool>>{};

    // 逐行解析
    for (var r = headerRow + 1; r < table.length; r++) {
      final row = table[r];
      var colOffset = 0;

      for (var c = 0; c < row.length; c++) {
        final cell = row[c];
        final text = cell['t'] as String;
        final cs = cell['cs'] as int;
        final rs = cell['rs'] as int;

        // 处理 colspan 导致的列偏移
        final actualCol = colOffset;
        colOffset += cs;

        // 跳过被 rowspan 占用的列
        if (occupied[r]?[actualCol] == true) continue;

        final day = dayMap[actualCol];
        if (day == null) continue;

        // 标记 rowspan 占用
        if (rs > 1) {
          for (var rr = r + 1; rr < r + rs && rr < table.length; rr++) {
            occupied.putIfAbsent(rr, () => {})[actualCol] = true;
          }
        }

        if (text.isEmpty) continue;

        // 提取节次范围（取所有数字的首尾）
        final periodNums = RegExp(r'\d+')
            .allMatches(text)
            .map((m) => int.parse(m.group(0)!))
            .where((n) => n >= 1 && n <= 13)
            .toList();
        if (periodNums.isEmpty) continue;
        final sp = periodNums.first;
        final ep = periodNums.last;

        // 节次号都在表头列（第一列），跳过
        if (dayMap[actualCol] != null && actualCol == 0) {
          // 第一列通常是节次标签，不是课程
          continue;
        }

        // 提取课程信息：按换行分割文本行
        final lines = text
            .split(RegExp(r'[\n\r]+'))
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        if (lines.isEmpty) continue;

        // 第一行通常是课程名
        final name = lines[0];
        // 后续行中找老师、地点
        String teacher = '';
        String location = '';

        for (var i = 1; i < lines.length; i++) {
          final line = lines[i];
          // 含数字+字母/汉字 → 可能是地点
          if (RegExp(r'[A-Za-z0-9一-鿿]').hasMatch(line) &&
              (line.contains('楼') || line.contains('室') || line.contains('教') || line.contains('实验'))) {
            location = line;
          } else if (line.length <= 10 && !line.contains('节')) {
            // 短文本 → 可能是老师名
            teacher = line;
          }
        }

        // 过滤非课程行（纯数字、节次标签等）
        if (name.length <= 3 &&
            RegExp(r'^[\d\s:：\-–—]+$').hasMatch(name)) {
          continue;
        }

        final colorIdx = name.runes.fold(0, (a, b) => a + b) % 10;

        courses.add(Course(
          id: 'imp_${DateTime.now().millisecondsSinceEpoch}_${courses.length}',
          name: name,
          teacher: teacher,
          location: location,
          dayOfWeek: day,
          startPeriod: sp,
          endPeriod: ep,
          colorIndex: colorIdx,
          weekCycle: WeekCycle.all,
        ));
      }
    }

    return courses;
  }

  // ─── JSON API 导入 ───

  Future<void> _tryImportJson(String raw) async {
    try {
      final data = jsonDecode(raw);
      List? list;
      if (data is Map) {
        for (final k in ['kbList', 'rows', 'data', 'datas', 'list']) {
          var v = data[k];
          if (v is List && v.isNotEmpty) {
            list = v;
            break;
          }
          if (k == 'datas' && v is Map) {
            for (final k2 in ['kbList', 'rows']) {
              var v2 = v[k2];
              if (v2 is List && v2.isNotEmpty) {
                list = v2;
                break;
              }
            }
          }
        }
      }
      if (list == null || list.isEmpty) {
        _log('未找到课程列表字段');
        return;
      }

      _log('找到 ${list.length} 条课程记录');
      final provider = context.read<CourseProvider>();
      await provider.clearAllCoursesForImport();
      int count = 0;

      final courses = <Course>[];
      for (final item in list) {
        if (item is! Map) continue;
        final m = item as Map<String, dynamic>;

        String s(String key, [String alt = '']) =>
            (m[key] ?? m[alt] ?? '').toString().trim();
        final name = s('kcmc');
        if (name.isEmpty) continue;

        String teacher = s('xm', 'jsxm');
        String location = s('cdmc', 'classroom');
        String dayStr = s('xqj', 'dayOfWeek');
        if (dayStr.isEmpty) dayStr = '1';
        int day = int.tryParse(dayStr) ?? 1;
        String secStr = s('jcs', 'skjc');
        String weekStr = s('zcd', 'skzc');
        if (weekStr.isEmpty) weekStr = '1-16周';

        final (sp, ep) = _parseSec(secStr.isEmpty ? '1-2节' : secStr);
        WeekCycle wc = WeekCycle.all;
        if (weekStr.contains('单')) wc = WeekCycle.odd;
        if (weekStr.contains('双')) wc = WeekCycle.even;
        int ci = name.runes.fold(0, (a, b) => a + b) % 10;

        courses.add(Course(
          id: 'imp_${DateTime.now().millisecondsSinceEpoch}_$count',
          name: name,
          teacher: teacher,
          location: location,
          dayOfWeek: day,
          startPeriod: sp,
          endPeriod: ep,
          colorIndex: ci,
          weekCycle: wc,
        ));
        count++;
      }

      await provider.batchInsertCourses(courses);
      setState(() {
        _captured = true;
        _status = '成功导入 $count 门课程';
      });
      _log('导入完成: $count 门课');
    } catch (e) {
      _log('导入失败: $e');
    }
  }

  // ─── 通用导入（HTML表格解析结果） ───

  Future<void> _importCourses(List<Course> courses) async {
    if (courses.isEmpty) return;

    _log('从HTML表格解析到 ${courses.length} 门课程');
    final provider = context.read<CourseProvider>();
    await provider.clearAllCoursesForImport();
    await provider.batchInsertCourses(courses);
    setState(() {
      _captured = true;
      _status = '成功导入 ${courses.length} 门课程';
    });
    _log('导入完成: ${courses.length} 门课');
  }

  (int, int) _parseSec(String s) {
    final numbers = RegExp(r'\d+')
        .allMatches(s)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    if (numbers.isEmpty) return (1, 2);
    return (numbers.first, numbers.last);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('从教务系统导入'),
        actions: [
          if (_captured)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('完成',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color:
                _captured ? cs.primaryContainer : cs.surfaceContainerHighest,
            child: Text(_status,
                style: TextStyle(
                    fontSize: 13,
                    color: _captured ? cs.primary : cs.onSurfaceVariant)),
          ),
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator()),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _captured ? null : _grabSchedule,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('导入课表'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_logs.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                controller: _logScrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text(_logs[i],
                    style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        height: 1.4)),
              ),
            ),
        ],
      ),
    );
  }
}
