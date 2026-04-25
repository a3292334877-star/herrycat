import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_model.dart';
import '../providers/course_provider.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late Course _course;
  bool _isEditing = false;
  
  late TextEditingController _nameController;
  late TextEditingController _teacherController;
  late TextEditingController _locationController;
  late int _selectedDay;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late Color _selectedColor;

  final List<Color> _colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.purple,
    Colors.red, Colors.teal, Colors.pink, Colors.indigo,
  ];

  final List<String> _dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _course = ModalRoute.of(context)!.settings.arguments as Course;
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: _course.name);
    _teacherController = TextEditingController(text: _course.teacher);
    _locationController = TextEditingController(text: _course.location);
    _selectedDay = _course.dayOfWeek;
    _startTime = _parseTime(_course.startTime);
    _endTime = _parseTime(_course.endTime);
    _selectedColor = _course.color;
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑课程' : '课程详情'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteCourse,
            ),
        ],
      ),
      body: _isEditing ? _buildEditForm() : _buildDetailView(),
    );
  }

  Widget _buildDetailView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _course.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _course.color, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_course.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildDetailRow(Icons.person, _course.teacher.isEmpty ? '未设置' : _course.teacher),
              _buildDetailRow(Icons.calendar_today, _course.dayName),
              _buildDetailRow(Icons.access_time, _course.timeSlot),
              _buildDetailRow(Icons.location_on, _course.location.isEmpty ? '未设置' : _course.location),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(text, style: const TextStyle(fontSize: 16))],
      ),
    );
  }

  Widget _buildEditForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: '课程名称', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _teacherController,
          decoration: const InputDecoration(labelText: '授课老师', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _selectedDay,
          decoration: const InputDecoration(labelText: '上课日期', border: OutlineInputBorder()),
          items: List.generate(7, (i) => i + 1)
              .map((d) => DropdownMenuItem(value: d, child: Text(_dayNames[d])))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedDay = v);
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(true),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '开始时间', border: OutlineInputBorder()),
                  child: Text(_formatTime(_startTime)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(false),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '结束时间', border: OutlineInputBorder()),
                  child: Text(_formatTime(_endTime)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(labelText: '上课地点', border: OutlineInputBorder()),
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
                border: _selectedColor == c ? Border.all(color: Colors.black, width: 3) : null,
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('保存修改', style: TextStyle(fontSize: 18)),
        ),
      ],
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

  Future<void> _saveChanges() async {
    final updated = _course.copyWith(
      name: _nameController.text,
      teacher: _teacherController.text,
      dayOfWeek: _selectedDay,
      startTime: _formatTime(_startTime),
      endTime: _formatTime(_endTime),
      location: _locationController.text,
      color: _selectedColor,
    );

    await context.read<CourseProvider>().updateCourse(updated);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('修改成功！')));
      Navigator.pop(context);
    }
  }

  Future<void> _deleteCourse() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${_course.name} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<CourseProvider>().deleteCourse(_course.id);
      Navigator.pop(context);
    }
  }
}