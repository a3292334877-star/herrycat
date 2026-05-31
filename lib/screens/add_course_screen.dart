import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_model.dart';
import '../providers/course_provider.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _nameCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  int _day = 1;
  int _startPeriod = 1;
  int _endPeriod = 2;
  int _colorIdx = 0;
  WeekCycle _cycle = WeekCycle.all;
  bool _editing = false;
  bool _saving = false;
  String? _editId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Course) {
        _editing = true;
        _editId = args.id;
        _nameCtrl.text = args.name;
        _teacherCtrl.text = args.teacher;
        _locationCtrl.text = args.location;
        _noteCtrl.text = args.note;
        _day = args.dayOfWeek;
        _startPeriod = args.startPeriod;
        _endPeriod = args.endPeriod;
        _colorIdx = args.colorIndex;
        _cycle = args.weekCycle;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _teacherCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? '编辑课程' : '添加课程'),
        actions: [
          TextButton(
            onPressed: _save,
            child:
                const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '课程名称',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _teacherCtrl,
              decoration: const InputDecoration(
                labelText: '授课老师',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: '上课地点',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text('星期',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (i) {
                final d = i + 1;
                final today = DateTime.now().weekday;
                final isNow = d == today;
                final selected = _day == d;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(Course.dayNames[i],
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      selected: selected,
                      onSelected: (_) => setState(() => _day = d),
                      avatar: isNow
                          ? Icon(Icons.today,
                              size: 14,
                              color: selected ? cs.onPrimary : cs.primary)
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Text('节次',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _startPeriod,
                    decoration: const InputDecoration(
                      labelText: '起始节',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(13, (i) => i + 1)
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('第$p节 ${Course.periodLabels[p - 1]}',
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _startPeriod = v!;
                        if (_endPeriod < _startPeriod) {
                          _endPeriod = _startPeriod;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _endPeriod,
                    decoration: const InputDecoration(
                      labelText: '结束节',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(13, (i) => i + 1)
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('第$p节 ${Course.periodLabels[p - 1]}',
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _endPeriod = v!;
                        if (_startPeriod > _endPeriod) {
                          _startPeriod = _endPeriod;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('周次',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            SegmentedButton<WeekCycle>(
              segments: const [
                ButtonSegment(value: WeekCycle.all, label: Text('全周')),
                ButtonSegment(value: WeekCycle.odd, label: Text('单周')),
                ButtonSegment(value: WeekCycle.even, label: Text('双周')),
              ],
              selected: {_cycle},
              onSelectionChanged: (s) => setState(() => _cycle = s.first),
            ),
            const SizedBox(height: 20),
            Text('颜色标签',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(Course.colors.length, (i) {
                final c = Color(Course.colors[i]);
                return GestureDetector(
                  onTap: () => setState(() => _colorIdx = i),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _colorIdx == i
                          ? Border.all(color: cs.onSurface, width: 3)
                          : null,
                      boxShadow: _colorIdx == i
                          ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6)]
                          : null,
                    ),
                    child: _colorIdx == i
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  void _save() async {
    if (_saving) return;
    _saving = true;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _saving = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入课程名称')),
      );
      return;
    }

    final provider = context.read<CourseProvider>();

    // 检查时间冲突
    for (final c in provider.courses) {
      if (_editId != null && c.id == _editId) continue;
      if (c.dayOfWeek != _day) continue;
      if (_cycle != WeekCycle.all &&
          c.weekCycle != WeekCycle.all &&
          _cycle != c.weekCycle) {
        continue;
      }
      if (_startPeriod <= c.endPeriod && _endPeriod >= c.startPeriod) {
        _saving = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('与「${c.name}」时间冲突，请调整节次或周次')),
          );
        }
        return;
      }
    }

    final course = Course(
      id: _editId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      teacher: _teacherCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      dayOfWeek: _day,
      startPeriod: _startPeriod,
      endPeriod: _endPeriod,
      colorIndex: _colorIdx,
      weekCycle: _cycle,
    );

    if (_editing) {
      await provider.updateCourse(course);
    } else {
      await provider.addCourse(course);
    }

    if (mounted) Navigator.pop(context, true);
  }
}
