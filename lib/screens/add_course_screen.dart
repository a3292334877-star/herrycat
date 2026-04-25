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
  
  int _selectedDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 40);
  Color _selectedColor = Colors.blue;
  bool _isRecurring = true;

  final List<Color> _colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.purple,
    Colors.red, Colors.teal, Colors.pink, Colors.indigo,
  ];

  final List<String> _dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

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
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '课程名称 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? '请输入课程名称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _teacherController,
              decoration: const InputDecoration(
                labelText: '授课老师',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
                const SizedBox(width: 16),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: '上课地点',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('每周重复'),
              subtitle: const Text('在本学期的每个相同星期几显示'),
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
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
        if (isStart) _startTime = time;
        else _endTime = time;
      });
    }
  }

  String _formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    final course = Course(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      teacher: _teacherController.text,
      dayOfWeek: _selectedDay,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      location: _locationController.text,
      color: _selectedColor,
      isRecurring: _isRecurring,
    );

    await context.read<CourseProvider>().addCourse(course);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('添加成功！')),
      );
      Navigator.pop(context);
    }
  }
}