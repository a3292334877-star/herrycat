import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/course_provider.dart';
import '../models/course_model.dart';
import '../widgets/course_table.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();
  int _selectedWeek = 1;
  bool _showWeekend = true;

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<CourseProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(provider.error!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              );
            }
            return Column(
              children: [
                _HeaderBar(
                  selectedWeek: _selectedWeek,
                  showWeekend: _showWeekend,
                  provider: provider,
                  onPrevWeek: () => setState(() => _selectedWeek--),
                  onNextWeek: () => setState(() => _selectedWeek++),
                  onToggleWeekend: () =>
                      setState(() => _showWeekend = !_showWeekend),
                  onImport: () => _importSchedule(provider),
                  onShare: () => _shareSchedule(provider),
                ),
                Expanded(
                  child: CourseTable(
                    provider: provider,
                    selectedWeek: _selectedWeek,
                    showWeekend: _showWeekend,
                    horizontalScroll: _hScroll,
                    verticalScroll: _vScroll,
                    onEdit: _editCourse,
                    onDelete: _deleteCourse,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _addCourse(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addCourse() async {
    final result = await Navigator.pushNamed(context, '/add');
    if (!mounted) return;
    if (result == true) {
      context.read<CourseProvider>().loadCourses();
    }
  }

  Future<void> _importSchedule(CourseProvider p) async {
    final result = await Navigator.pushNamed(context, '/import');
    if (!mounted) return;
    if (result == true) {
      p.loadCourses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('课表导入成功'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _editCourse(Course course) async {
    final result =
        await Navigator.pushNamed(context, '/add', arguments: course);
    if (!mounted) return;
    if (result == true) {
      context.read<CourseProvider>().loadCourses();
    }
  }

  void _deleteCourse(Course course, CourseProvider p) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确定要删除「${course.name}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              p.deleteCourse(course.id);
              Navigator.pop(ctx);
            },
            child: Text('删除', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }

  void _shareSchedule(CourseProvider p) {
    final buf = StringBuffer();
    buf.writeln('Henrycat 课表');
    buf.writeln('=' * 20);
    for (int d = 1; d <= 7; d++) {
      final courses = p.getCoursesForDay(d);
      buf.writeln('\n周${Course.dayNames[d - 1]}:');
      if (courses.isEmpty) {
        buf.writeln('  无课');
      } else {
        for (final c in courses) {
          buf.writeln(
              '  ${c.timeSlot}  ${c.fullName}  @${c.location}  ${c.teacher}');
        }
      }
    }
    Share.share(buf.toString(), subject: 'Henrycat 课表');
  }
}

class _HeaderBar extends StatelessWidget {
  final int selectedWeek;
  final bool showWeekend;
  final CourseProvider provider;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onToggleWeekend;
  final VoidCallback onImport;
  final VoidCallback onShare;

  const _HeaderBar({
    required this.selectedWeek,
    required this.showWeekend,
    required this.provider,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onToggleWeekend,
    required this.onImport,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border:
            Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Row(
        children: [
          Text('Henrycat',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: cs.primary)),
          const SizedBox(width: 4),
          Text('课表',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: selectedWeek > 1 ? onPrevWeek : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            label: Text('第$selectedWeek周'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: onNextWeek,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
                showWeekend ? Icons.calendar_month : Icons.calendar_today,
                size: 20),
            tooltip: showWeekend ? '隐藏周末' : '显示周末',
            onPressed: onToggleWeekend,
            visualDensity: VisualDensity.compact,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 20),
            onSelected: (v) => switch (v) {
              'import' => onImport(),
              'share' => onShare(),
              'settings' => Navigator.pushNamed(context, '/settings'),
              'about' => Navigator.pushNamed(context, '/about'),
              _ => {},
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                      leading: Icon(Icons.download),
                      title: Text('从教务导入'),
                      dense: true)),
              const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                      leading: Icon(Icons.share),
                      title: Text('分享课表'),
                      dense: true)),
              const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('设置'),
                      dense: true)),
              const PopupMenuItem(
                  value: 'about',
                  child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('关于'),
                      dense: true)),
            ],
          ),
        ],
      ),
    );
  }
}
