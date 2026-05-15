import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/course_provider.dart';
import '../models/course_model.dart';
import '../widgets/course_card.dart';
import '../widgets/weekly_grid_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _weeklyGridMode = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1C1E21) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1E21) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        scrolledUnderElevation: isDark ? 0 : 1,
        title: const Text('课程表', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_weeklyGridMode ? 48 : 96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: '搜索课程...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2C2E33) : Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              if (!_weeklyGridMode)
                SizedBox(
                  height: 40,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: isDark ? Colors.white : Colors.black87,
                    unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
                    indicatorColor: colorScheme.primary,
                    indicatorWeight: 3,
                    dividerColor: Colors.transparent,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tabs: _dayNames.map((d) => Tab(text: d)).toList(),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_weeklyGridMode ? Icons.view_list : Icons.grid_view, color: isDark ? Colors.white : Colors.black87),
            tooltip: _weeklyGridMode ? '切换列表' : '切换周视图',
            onPressed: () => setState(() => _weeklyGridMode = !_weeklyGridMode),
          ),
          IconButton(
            icon: Icon(Icons.bar_chart, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pushNamed(context, '/statistics'),
          ),
          IconButton(
            icon: Icon(Icons.download, color: isDark ? Colors.white : Colors.black87),
            tooltip: '导入课表',
            onPressed: _importSchedule,
          ),
          IconButton(
            icon: Icon(Icons.share, color: isDark ? Colors.white : Colors.black87),
            onPressed: _shareSchedule,
          ),
          IconButton(
            icon: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (_searchQuery.isNotEmpty) {
            final results = provider.courses
                .where((c) => c.name.toLowerCase().contains(_searchQuery))
                .toList();
            return _buildSearchResults(results);
          }

          if (_weeklyGridMode) {
            return const WeeklyGridView();
          }

          return TabBarView(
            controller: _tabController,
            children: List.generate(7, (index) {
              final day = index + 1;
              final courses = provider.getCoursesForDay(day);
              return _buildCourseList(courses, day);
            }),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.pushNamed(context, '/add'),
        child: Icon(Icons.add, color: isDark ? Colors.white : Colors.white),
      ),
    );
  }

  Widget _buildSearchResults(List<Course> courses) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '没有找到"$_searchQuery"相关的课程',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: courses.length,
      itemBuilder: (context, i) {
        final course = courses[i];
        return CourseCard(
          course: course,
          onTap: () => _showCourseDetail(course),
          onLongPress: () => _showSwapDialog(course),
        );
      },
    );
  }

  Widget _buildCourseList(List<Course> courses, int day) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '这天没课～',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: courses.length,
      itemBuilder: (context, i) {
        final course = courses[i];
        return CourseCard(
          course: course,
          onTap: () => _showCourseDetail(course),
          onLongPress: () => _showSwapDialog(course),
        );
      },
    );
  }

  void _showCourseDetail(Course course) {
    Navigator.pushNamed(context, '/detail', arguments: course);
  }

  void _showSwapDialog(Course course) {
    final provider = context.read<CourseProvider>();
    final courses = provider.getCoursesForDay(course.dayOfWeek);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2E33) : Colors.white,
        title: Text('换课', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final other = courses[index];
              if (other.id == course.id) return const SizedBox.shrink();
              return ListTile(
                title: Text(other.name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                subtitle: Text(other.timeSlot, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                onTap: () {
                  provider.swapCourses(course.id, other.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('换课成功！')),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _shareSchedule() {
    final provider = context.read<CourseProvider>();
    final buffer = StringBuffer();
    buffer.writeln('📚 Herrycat 课程表');
    buffer.writeln('================');

    final dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    for (int day = 1; day <= 7; day++) {
      final courses = provider.getCoursesForDay(day);
      buffer.writeln('\n${dayNames[day - 1]}:');
      if (courses.isEmpty) {
        buffer.writeln('  无课');
      } else {
        for (final course in courses) {
          buffer.writeln('  • ${course.name} ${course.startTime}-${course.endTime} @${course.location}');
        }
      }
    }

    Share.share(buffer.toString(), subject: 'Herrycat 课程表');
  }

  Future<void> _importSchedule() async {
    final result = await Navigator.pushNamed(context, '/import');
    if (result == true && mounted) {
      context.read<CourseProvider>().loadCourses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ 课表导入成功！'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
