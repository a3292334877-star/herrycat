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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teacherController = TextEditingController();
  final _locationController = TextEditingController();
  final _creditsController = TextEditingController(text: '2.5');

  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 40);
  Color _selectedColor = Colors.blue;
  WeekCycle _weekCycle = WeekCycle.all;
  CourseNature _nature = CourseNature.required;
  String _weekRange = '1-16周';

  final List<Color> _colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.purple,
    Colors.red, Colors.teal, Colors.pink, Colors.indigo,
  ];

  final List<String> _dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  final List<String> _weekRanges = [
    '1-16周', '1-18周', '1-8周', '9-16周', '1-6周', '7-12周',
    '1-10周', '11-18周', '1-14周', '1-20周', '1-4周', '5-8周',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加课程'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 课程名称
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '课程名称 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? '请输入课程名称' : null,
            ),
            const SizedBox(height: 12),

            // 授课老师
            TextFormField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: '授课老师',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 上课日期
            DropdownButtonFormField<int>(
              value: _selectedDay,
              decoration: const InputDecoration(
                labelText: '上课日期 *',
                border: OutlineInputBorder(),
              ),
              items: List.generate(7, (i) => i + 1)
                  .map((d) => DropdownMenuItem(value: d, child: Text(_dayNames[d])))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDay = v!),
            ),
            const SizedBox(height: 12),

            // 时间选择
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '开始时间 *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_formatTime(_startTime)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '结束时间 *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_formatTime(_endTime)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 上课地点
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '上课地点',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // 课程性质
            const Text('课程性质', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            SegmentedButton<CourseNature>(
              segments: const [
                ButtonSegment(value: CourseNature.required, label: Text('必修')),
                ButtonSegment(value: CourseNature.elective, label: Text('选修')),
                ButtonSegment(value: CourseNature.public, label: Text('公选')),
              ],
              selected: {_nature},
              onSelectionChanged: (set) => setState(() => _nature = set.first),
            ),
            const SizedBox(height: 12),

            // 学分
            TextFormField(
              controller: _creditsController,
              decoration: const InputDecoration(
                labelText: '学分',
                border: OutlineInputBorder(),
                suffixText: '学分',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            // 周数范围
            DropdownButtonFormField<String>(
              value: _weekRange,
              decoration: const InputDecoration(
                labelText: '周数范围',
                border: OutlineInputBorder(),
              ),
              items: _weekRanges
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _weekRange = v!),
            ),
            const SizedBox(height: 12),

            // 周次
            const Text('周次', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            SegmentedButton<WeekCycle>(
              segments: const [
                ButtonSegment(value: WeekCycle.all, label: Text('全周')),
                ButtonSegment(value: WeekCycle.odd, label: Text('单周')),
                ButtonSegment(value: WeekCycle.even, label: Text('双周')),
              ],
              selected: {_weekCycle},
              onSelectionChanged: (set) => setState(() => _weekCycle = set.first),
            ),
            const SizedBox(height: 12),

            // 课程颜色
            const Text('课程颜色', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((c) => GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: _selectedColor == c
                        ? Border.all(color: Colors.black, width: 3)
                        : null,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saveCourse,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('保存', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    final credits = double.tryParse(_creditsController.text) ?? 2.5;

    final course = Course(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      teacher: _teacherController.text,
      dayOfWeek: _selectedDay,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      location: _locationController.text,
      color: _selectedColor,
      weekCycle: _weekCycle,
      nature: _nature,
      credits: credits,
      weekRange: _weekRange,
    );

    final provider = context.read<CourseProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await provider.addCourse(course);
      messenger.showSnackBar(
        SnackBar(
          content: Text('✅ ${course.name} 添加成功'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('添加失败: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
