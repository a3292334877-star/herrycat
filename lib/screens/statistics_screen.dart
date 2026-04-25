import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课程统计'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          final courses = provider.courses;
          final totalCourses = courses.length;
          final totalHours = _calculateTotalHours(courses);
          final classroomUsage = _calculateClassroomUsage(courses);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatCard(
                context,
                icon: Icons.book,
                title: '课程总数',
                value: '$totalCourses',
                subtitle: '门课程',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                context,
                icon: Icons.access_time,
                title: '每周总课时',
                value: '${totalHours.toStringAsFixed(1)}',
                subtitle: '小时/周',
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                '📍 教室使用情况',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              if (classroomUsage.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.meeting_room, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('暂无教室数据', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                )
              else
                ...classroomUsage.entries.map((entry) => _buildClassroomTile(
                      context,
                      location: entry.key,
                      count: entry.value,
                      total: courses.length,
                    )),
              const SizedBox(height: 24),
              Text(
                '📊 每日课程分布',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _buildDayDistribution(context, courses),
            ],
          );
        },
      ),
    );
  }

  double _calculateTotalHours(List courses) {
    double total = 0;
    for (final course in courses) {
      final startParts = course.startTime.split(':');
      final endParts = course.endTime.split(':');
      final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      total += (endMinutes - startMinutes) / 60;
    }
    return total;
  }

  Map<String, int> _calculateClassroomUsage(List courses) {
    final Map<String, int> usage = {};
    for (final course in courses) {
      if (course.location.isNotEmpty) {
        usage[course.location] = (usage[course.location] ?? 0) + 1;
      }
    }
    return Map.fromEntries(
      usage.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassroomTile(
    BuildContext context, {
    required String location,
    required int count,
    required int total,
  }) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: const Icon(Icons.location_on, color: Colors.orange),
        ),
        title: Text(location),
        subtitle: LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
        trailing: Text(
          '$count 节课\n${percentage.toStringAsFixed(0)}%',
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDayDistribution(BuildContext context, List courses) {
    final dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dayCounts = List.generate(7, (i) {
      final day = i + 1;
      return courses.where((c) => c.dayOfWeek == day).length;
    });
    final maxCount = dayCounts.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(7, (i) {
            final count = dayCounts[i];
            final percentage = maxCount > 0 ? count / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(dayNames[i], style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Text('$count', textAlign: TextAlign.right),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}