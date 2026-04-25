import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../models/course_model.dart';

/// Weekly grid view with prev/next week navigation.
/// Shows all courses for a chosen week across Mon-Sun columns.
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

  static const double _timeColW = 44.0;
  static const double _headerH = 38.0;
  static const double _rowH = 50.0;
  static const double _colW = 48.0;

  @override
  Widget build(BuildContext context) {
    return Consumer2<CourseProvider, SettingsProvider>(
      builder: (context, courseProvider, settings, child) {
        if (courseProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final weekNum = settings.currentWeek;
        final courses = courseProvider.courses;
        final dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

        return Column(
          children: [
            // ── Week selector bar ──────────────────────────────────────
            _buildWeekBar(context, settings, weekNum),
            // ── Day-name header ───────────────────────────────────────
            _buildHeader(dayNames),
            // ── Scrollable grid ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _timeColW + 7 * _colW,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeColumn(),
                      ...List.generate(7, (dayIdx) {
                        final day = dayIdx + 1;
                        final dayCourses = courses
                            .where((c) => c.dayOfWeek == day && c.shouldShowInWeek(weekNum))
                            .toList();
                        return _buildDayColumn(dayCourses);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
              if (settings.currentWeek > 1) {
                settings.setCurrentWeek(settings.currentWeek - 1);
              }
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: () {
              if (settings.currentWeek < 20) {
                settings.setCurrentWeek(settings.currentWeek + 1);
              }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text('选择周次', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.6,
                ),
                itemCount: 20,
                itemBuilder: (ctx, i) {
                  final w = i + 1;
                  final isSelected = w == current;
                  return InkWell(
                    onTap: () {
                      settings.setCurrentWeek(w);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5B9BF5)
                            : const Color(0xFF3A3D41),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '$w',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
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

  Widget _buildHeader(List<String> dayNames) {
    return SizedBox(
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    return SizedBox(
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
                padding: const EdgeInsets.only(right: 4, top: 2),
                child: Text(
                  slot.start,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 9,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(List<Course> dayCourses) {
    return SizedBox(
      width: _colW,
      height: _slots.length * _rowH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: List.generate(_slots.length, (i) {
              return SizedBox(
                width: _colW,
                height: _rowH,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey[850]!, width: 0.5),
                      right: BorderSide(color: Colors.grey[850]!, width: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          ...dayCourses.map((c) => _buildCourseBlock(c)),
        ],
      ),
    );
  }

  Widget _buildCourseBlock(Course course) {
    final (top, height) = _calcPosition(course.startTime, course.endTime);

    return Positioned(
      top: top,
      left: 1,
      right: 1,
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: course.color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                course.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (course.location.isNotEmpty && height > 24)
              Flexible(
                child: Text(
                  course.location,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 7,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  (double, double) _calcPosition(String startTime, String endTime) {
    final startMin = _parseTime(startTime);
    final endMin = _parseTime(endTime);
    const startOfDay = 8 * 60;
    const rowH = _rowH;

    final top = ((startMin - startOfDay) / 45) * rowH;
    final bottom = ((endMin - startOfDay) / 45) * rowH;
    return (top.clamp(0.0, double.infinity), (bottom - top).clamp(18.0, double.infinity));
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
