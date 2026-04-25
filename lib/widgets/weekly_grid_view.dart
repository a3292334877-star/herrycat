import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../models/course_model.dart';
import '../widgets/course_card.dart';

/// Weekly grid view: 7 day columns + time rows, all visible at once
class WeeklyGridView extends StatelessWidget {
  const WeeklyGridView({super.key});

  static const List<_TimeSlot> _slots = [
    _TimeSlot(1, '08:00', '08:45'),
    _TimeSlot(2, '08:50', '09:35'),
    _TimeSlot(3, '09:55', '10:40'),
    _TimeSlot(4, '10:45', '11:30'),
    _TimeSlot(5, '11:35', '12:20'),
    _TimeSlot(6, '14:00', '14:45'),
    _TimeSlot(7, '14:50', '15:35'),
    _TimeSlot(8, '15:55', '16:40'),
    _TimeSlot(9, '16:45', '17:30'),
    _TimeSlot(10, '17:35', '18:20'),
    _TimeSlot(11, '19:00', '19:45'),
    _TimeSlot(12, '19:50', '20:35'),
    _TimeSlot(13, '20:40', '21:25'),
    _TimeSlot(14, '21:30', '22:15'),
  ];

  static const double _colW = 110.0;
  static const double _rowH = 52.0;
  static const double _timeColW = 46.0;
  static const double _headerH = 42.0;

  @override
  Widget build(BuildContext context) {
    return Consumer<CourseProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final courses = provider.courses;
        final dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

        return Column(
          children: [
            // Header row: time col + 7 day headers
            SizedBox(
              height: _headerH,
              child: Row(
                children: [
                  SizedBox(width: _timeColW, height: _headerH),
                  ...List.generate(7, (i) => SizedBox(
                    width: _colW,
                    height: _headerH,
                    child: Center(
                      child: Text(
                        dayNames[i],
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
            // Grid body
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time label column
                    SizedBox(
                      width: _timeColW,
                      child: Column(
                        children: List.generate(_slots.length, (i) {
                          final slot = _slots[i];
                          return SizedBox(
                            width: _timeColW,
                            height: _rowH,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6, top: 4),
                                child: Text(
                                  '${slot.start}\n${slot.end}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 9,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Day columns
                    ...List.generate(7, (dayIdx) {
                      final day = dayIdx + 1;
                      final dayCourses = courses.where((c) => c.dayOfWeek == day).toList();

                      return SizedBox(
                        width: _colW,
                        child: Stack(
                          children: [
                            // Grid lines
                            Column(
                              children: List.generate(_slots.length, (i) {
                                return Container(
                                  width: _colW,
                                  height: _rowH,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.grey[850]!, width: 0.5),
                                      right: BorderSide(color: Colors.grey[850]!, width: 0.5),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            // Course blocks
                            ...dayCourses.map((c) => _buildCourseBlock(c, dayCourses)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCourseBlock(Course course, List<Course> dayCourses) {
    final (top, height) = _calcPosition(course.startTime, course.endTime);
    final sameSlot = dayCourses.where((c) =>
      c.id != course.id &&
      c.startTime == course.startTime &&
      c.endTime == course.endTime &&
      c.dayOfWeek == course.dayOfWeek
    ).length;
    final offset = sameSlot > 0 ? 0.0 : 0.0;

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final blockW = constraints.maxWidth;
          return Container(
            width: blockW,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: course.color.withOpacity(0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                course.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (course.location.isNotEmpty && height > 30) ...[
                Text(
                  course.location,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (course.weekCycle != WeekCycle.all && height > 44) ...[
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    course.weekCycleLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 7),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  (double, double) _calcPosition(String startTime, String endTime) {
    // Parse times
    final startMin = _parseTime(startTime);
    final endMin = _parseTime(endTime);

    // Grid starts at 08:00 = 480 min, each row = 52dp for 45 min (or 60 min span)
    const startOfDay = 8 * 60; // 480 min
    const rowHeight = _rowH;

    final top = ((startMin - startOfDay) / 45) * rowHeight;
    final bottom = ((endMin - startOfDay) / 45) * rowHeight;
    return (top.clamp(0, double.infinity), (bottom - top).clamp(24, double.infinity));
  }

  int _parseTime(String t) {
    final parts = t.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

class _TimeSlot {
  final int section;
  final String start;
  final String end;
  const _TimeSlot(this.section, this.start, this.end);
}
