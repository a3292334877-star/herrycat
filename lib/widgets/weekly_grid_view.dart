import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../models/course_model.dart';

/// Weekly grid view: fits entirely on screen, no scrolling needed.
/// Uses screen-width division to size columns, compressed timeline.
class WeeklyGridView extends StatelessWidget {
  const WeeklyGridView({super.key});

  static const int _dayStartMin = 8 * 60 + 30; // 510
  static const int _dayEndMin   = 20 * 60 + 30; // 1230
  static const int _totalMin    = _dayEndMin - _dayStartMin; // 720

  // Container height = 12 hours × 45 px/h = 540 px total
  static const double _containerH = 540.0;

  static double _minToPx(int min) =>
      ((min - _dayStartMin) / _totalMin) * _containerH;

  @override
  Widget build(BuildContext context) {
    return Consumer2<CourseProvider, SettingsProvider>(
      builder: (context, courseProvider, settings, child) {
        if (courseProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final weekNum  = settings.currentWeek;
        final courses  = courseProvider.courses;
        final dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

        return LayoutBuilder(
          builder: (context, constraints) {
            // Divide available width evenly across 8 parts (time col + 7 days)
            final colW = (constraints.maxWidth - 50) / 7;

            return Column(
              children: [
                _buildWeekBar(context, settings, weekNum),
                _buildHeader(dayNames, colW),
                Expanded(
                  child: _buildGrid(courses, weekNum, colW),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWeekBar(BuildContext context, SettingsProvider settings, int weekNum) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFF1C1E21),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () {
              if (settings.currentWeek > 1) settings.setCurrentWeek(settings.currentWeek - 1);
            },
          ),
          GestureDetector(
            onTap: () => _showWeekPicker(context, settings, weekNum),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2E33),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '第 $weekNum 周',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () {
              if (settings.currentWeek < 20) settings.setCurrentWeek(settings.currentWeek + 1);
            },
          ),
        ],
      ),
    );
  }

  void _showWeekPicker(BuildContext context, SettingsProvider settings, int current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2E33),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SizedBox(
        height: 300,
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('选择周次', style: TextStyle(color: Colors.white, fontSize: 16))),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.6),
                itemCount: 20,
                itemBuilder: (ctx, i) {
                  final w = i + 1;
                  final isSelected = w == current;
                  return InkWell(
                    onTap: () { settings.setCurrentWeek(w); Navigator.pop(ctx); },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF5B9BF5) : const Color(0xFF3A3D41),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text('$w', style: TextStyle(color: isSelected ? Colors.white : Colors.grey[400], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<String> dayNames, double colW) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          const SizedBox(width: 42, height: 24),
          ...List.generate(7, (i) => SizedBox(
            width: colW,
            height: 24,
            child: Center(child: Text(dayNames[i], style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w600))),
          )),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Course> courses, int weekNum, double colW) {
    return Row(
      children: [
        // Time column
        SizedBox(
          width: 42,
          height: _containerH,
          child: Stack(
            children: [
              ...[9, 11, 13, 15, 17, 19].map((h) => Positioned(
                top: _minToPx(h * 60) - 0.25,
                left: 0, right: 0,
                child: Container(height: 0.5, color: Colors.grey[850]),
              )),
              ...[9, 11, 13, 15, 17, 19].map((h) => Positioned(
                top: _minToPx(h * 60) - 7,
                left: 4, right: 4,
                child: Text('${h.toString().padLeft(2, '0')}:00',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.grey[600], fontSize: 8, height: 1.2)),
              )),
            ],
          ),
        ),
        // 7 day columns
        ...List.generate(7, (i) {
          final day = i + 1;
          final dayCourses = courses
              .where((c) => c.dayOfWeek == day && c.shouldShowInWeek(weekNum))
              .toList();
          return SizedBox(
            width: colW,
            height: _containerH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ...[9, 11, 13, 15, 17, 19].map((h) => Positioned(
                  top: _minToPx(h * 60) - 0.25,
                  left: 0, right: 0,
                  child: Container(height: 0.5, color: Colors.grey[850]),
                )),
                ...dayCourses.map((c) => _CourseBlock(course: c, colW: colW)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Course block ─────────────────────────────────────────────────────────────
class _CourseBlock extends StatelessWidget {
  final Course course;
  final double colW;
  const _CourseBlock({required this.course, required this.colW});

  @override
  Widget build(BuildContext context) {
    final topPx    = _topPx();
    final heightPx = _heightPx();

    return Positioned(
      top: topPx,
      left: 1,
      right: 1,
      height: heightPx,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: course.color.withOpacity(0.92),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              course.name,
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (course.location.isNotEmpty && heightPx > 22) ...[
              const SizedBox(height: 1),
              Text(course.location, style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 7), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  double _topPx() {
    final parts = course.startTime.split(':');
    final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    return WeeklyGridView._minToPx(startMin);
  }

  double _heightPx() {
    final sp = course.startTime.split(':');
    final ep = course.endTime.split(':');
    final startMin = int.parse(sp[0]) * 60 + int.parse(sp[1]);
    final endMin   = int.parse(ep[0]) * 60 + int.parse(ep[1]);
    final durMin   = endMin - startMin;
    return ((durMin / WeeklyGridView._totalMin) * WeeklyGridView._containerH).clamp(14.0, double.infinity);
  }
}
