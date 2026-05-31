import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course_model.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('外观',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildThemeSelector(context),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('数据管理',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: const Text('添加示例课表'),
                    subtitle: const Text('快速填充演示数据'),
                    onTap: () => _showImportDialog(context),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: cs.error),
                    title:
                        Text('清除所有数据', style: TextStyle(color: cs.error)),
                    onTap: () => _showClearDialog(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
        ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
        ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
      ],
      selected: {settings.themeMode},
      onSelectionChanged: (s) => settings.setThemeMode(s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: cs.primaryContainer,
        selectedForegroundColor: cs.onPrimaryContainer,
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加示例课表'),
        content: const Text('将添加一份示例课表，包含高等数学、大学英语等课程。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addSampleData(context);
              },
              child: const Text('导入')),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除所有数据'),
        content: const Text('这将删除所有课程数据且不可恢复。确定吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<CourseProvider>().clearAllCourses();
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清除所有数据')),
                );
              }
            },
            child: Text('清除', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }

  void _addSampleData(BuildContext context) async {
    final provider = context.read<CourseProvider>();
    final now = DateTime.now().microsecondsSinceEpoch;

    final samples = [
      ('高等数学', '张伟', 1, 1, 2, '教A101', 0, WeekCycle.all),
      ('大学英语', '李明', 1, 3, 4, '教B203', 1, WeekCycle.all),
      ('C语言程序设计', '王芳', 2, 1, 3, '实验楼301', 2, WeekCycle.odd),
      ('体育', '陈强', 2, 6, 7, '体育馆', 3, WeekCycle.all),
      ('数据结构', '刘洋', 3, 1, 2, '教A205', 4, WeekCycle.all),
      ('马克思主义原理', '赵敏', 3, 3, 4, '教C102', 5, WeekCycle.even),
      ('大学物理', '孙磊', 4, 1, 2, '教A301', 0, WeekCycle.all),
      ('线性代数', '周杰', 4, 6, 7, '教B105', 1, WeekCycle.all),
      ('英语听力', '李明', 5, 1, 2, '语音室201', 2, WeekCycle.all),
      ('程序设计实践', '王芳', 5, 3, 5, '实验楼301', 3, WeekCycle.odd),
    ];

    final courses = <Course>[];
    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      courses.add(Course(
        id: '${now}_$i',
        name: s.$1,
        teacher: s.$2,
        dayOfWeek: s.$3,
        startPeriod: s.$4,
        endPeriod: s.$5,
        location: s.$6,
        colorIndex: s.$7,
        weekCycle: s.$8,
      ));
    }

    await provider.batchInsertCourses(courses);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${courses.length} 门示例课程')),
      );
    }
  }
}
