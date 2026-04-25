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
  int _currentNavIndex = 0;

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
    return Scaffold(
      backgroundColor: const Color(0xFF1C1E21),
      appBar: _currentNavIndex == 0 ? _buildAppBar() : null,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentNavIndex,
        onTap: (i) => setState(() => _currentNavIndex = i),
      ),
      floatingActionButton: _currentNavIndex == 0
          ? Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF5B9BF5).withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B9BF5).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: FloatingActionButton(
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: () => Navigator.pushNamed(context, '/add'),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
            )
          : null,
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(_weeklyGridMode ? 48 : 96),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '搜索课程...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
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
                fillColor: const Color(0xFF2C2E33),
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
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[500],
                indicatorColor: const Color(0xFF5B9BF5),
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: _dayNames.map((d) => Tab(text: d)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_currentNavIndex != 0) {
      return const SizedBox.shrink();
    }
    return Consumer<CourseProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
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
            return _buildCourseList(courses);
          }),
        );
      },
    );
  }

  Widget _buildSearchResults(List<Course> courses) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('没有找到"$_searchQuery"相关的课程', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: courses.length,
      itemBuilder: (context, i) => CourseCard(
        course: courses[i],
        onTap: () => _showCourseDetail(courses[i]),
        onLongPress: () => _showSwapDialog(courses[i]),
      ),
    );
  }

  Widget _buildCourseList(List<Course> courses) {
    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('这天没课～', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: courses.length,
      itemBuilder: (context, i) => CourseCard(
        course: courses[i],
        onTap: () => _showCourseDetail(courses[i]),
        onLongPress: () => _showSwapDialog(courses[i]),
      ),
    );
  }

  void _showCourseDetail(Course course) {
    Navigator.pushNamed(context, '/detail', arguments: course);
  }

  void _showSwapDialog(Course course) {
    final provider = context.read<CourseProvider>();
    final courses = provider.getCoursesForDay(course.dayOfWeek);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2E33),
        title: const Text('换课', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final other = courses[index];
              if (other.id == course.id) return const SizedBox.shrink();
              return ListTile(
                title: Text(other.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(other.timeSlot, style: TextStyle(color: Colors.grey[400])),
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
    buffer.writeln('📚 Henrycat 课程表');
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
    Share.share(buffer.toString(), subject: 'Henrycat 课程表');
  }

  Future<void> _importSchedule() async {
    final result = await Navigator.pushNamed(context, '/import');
    if (result == true && mounted) {
      context.read<CourseProvider>().loadCourses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ 课表导入成功！'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E21),
        border: Border(top: BorderSide(color: Colors.grey[850]!, width: 0.5)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home_rounded, label: '首页', isSelected: currentIndex == 0, onTap: () => onTap(0)),
            _NavItem(icon: Icons.bar_chart_rounded, label: '统计', isSelected: currentIndex == 1, onTap: () => onTap(1)),
            _NavItem(icon: Icons.download_rounded, label: '导入', isSelected: currentIndex == 2, onTap: () => onTap(2)),
            _NavItem(icon: Icons.settings_rounded, label: '设置', isSelected: currentIndex == 3, onTap: () => onTap(3)),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFF5B9BF5) : Colors.grey[600]!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
