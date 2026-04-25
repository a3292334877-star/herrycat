import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../models/course_model.dart';

/// Weekly grid view with prev/next week navigation.
/// Uses absolute minute-based positioning so merged slots (e.g. 85-min)
/// and any duration align perfectly on the timeline.
class WeeklyGridView extends StatelessWidget {
  const WeeklyGridView({super.key});

  // ── Timeline constants ───────────────────────────────────────────────────
  // Day: 08:30 (510 min) → 20:30 (1230 min) = 720 total minutes
  static const int _dayStartMin = 8 * 60 + 30; // 510
  static const int _dayEndMin   = 20 * 60 + 30; // 1230
  static const int _totalMin    = _dayEndMin - _dayStartMin; // 720

  // Fixed pixel height: each hour = 105 px  →  12 h × 105 = 1260 px total
  static const double _containerH = 1260.0;
  static const double _hourH      = 105.0;
  static const double _timeColW   = 50.0;
  static const double _colW       = 56.0;

  // Convert minutes-since-08:30 → pixels
  static double _minToPx(int min) =>
      ((min - _dayStartMin) / _totalMin) * _containerH;

  // ── Hour-grid line positions (in px from top) ───────────────────────────
  // Every full hour from 09:00 → 20:00
  static double _hourPx(int hour) =>
      _minToPx(hour * 60); // e.g. hour=9 → min=540 → px

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

        return Column(
          children: [
            _buildWeekBar(context, settings, weekNum),
            _buildHeader(dayNames),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _timeColW + 7 * _colW,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TimeColumn(),
                      ...List.generate(7, (i) {
                        final day = i + 1;
                        final dayCourses = courses
                            .where((c) => c.dayOfWeek == day && c.shouldShowInWeek(weekNum))
                            .toList();
                        return _DayColumn(dayCourses);
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择周次', style: TextStyle(color: Colors.white, fontSize: 16)),
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
      height: 36,
      child: Row(
        children: [
          SizedBox(width: _timeColW, height: 36),
          ...List.generate(7, (i) => SizedBox(
            width: _colW,
            height: 36,
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
}

// ── Time-label column (left, fixed) ────────────────────────────────────────
class _TimeColumn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Hour labels: 09:00, 11:00, 13:00, 15:00, 17:00, 19:00
    // (08:30 label at very top edge, 20:30 at bottom edge — omitted for space)
    final hourLabels = [9, 11, 13, 15, 17, 19];

    return SizedBox(
      width: WeeklyGridView._timeColW,
      height: WeeklyGridView._containerH,
      child: Stack(
        children: [
          // Hour grid lines (vertical dashed look)
          ...hourLabels.map((h) => Positioned(
            top: WeeklyGridView._hourPx(h),
            left: 0,
            right: 0,
            child: Container(
              height: 0.5,
              color: Colors.grey[850],
            ),
          )),
          // Time labels
          ...hourLabels.map((h) => Positioned(
            top: WeeklyGridView._hourPx(h) - 8,
            left: 0,
            right: 4,
            child: Text(
              '${h.toString().padLeft(2, '0')}:00',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 9,
                height: 1.2,
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ── Single day column ───────────────────────────────────────────────────────
class _DayColumn extends StatelessWidget {
  final List<Course> courses;
  const _DayColumn(this.courses);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: WeeklyGridView._colW,
      height: WeeklyGridView._containerH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hour grid lines
          ...[9, 11, 13, 15, 17, 19].map((h) => Positioned(
            top: WeeklyGridView._hourPx(h),
            left: 0,
            right: 0,
            child: Container(height: 0.5, color: Colors.grey[850]),
          )),
          // Course blocks
          ...courses.map((c) => _CourseBlock(course: c)),
        ],
      ),
    );
  }
}

// ── Course block (positioned by actual minutes) ────────────────────────────
class _CourseBlock extends StatelessWidget {
  final Course course;
  const _CourseBlock({required this.course});

  @override
  Widget build(BuildContext context) {
    final topPx    = _courseTopPx();
    final heightPx = _courseHeightPx();

    return Positioned(
      top: topPx,
      left: 1,
      right: 1,
      height: heightPx,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        decoration: BoxDecoration(
          color: course.color.withOpacity(0.92),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              course.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (course.location.isNotEmpty && heightPx > 28) ...[
              const SizedBox(height: 1),
              Text(
                course.location,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.80),
                  fontSize: 8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (course.weekCycle != WeekCycle.all && heightPx > 44) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  course.weekCycleLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _courseTopPx() {
    final parts = course.startTime.split(':');
    final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    return WeeklyGridView._minToPx(startMin);
  }

  double _courseHeightPx() {
    final sp = course.startTime.split(':');
    final ep = course.endTime.split(':');
    final startMin = int.parse(sp[0]) * 60 + int.parse(sp[1]);
    final endMin   = int.parse(ep[0]) * 60 + int.parse(ep[1]);
    final durMin   = endMin - startMin;
    return ((durMin / WeeklyGridView._totalMin) * WeeklyGridView._containerH)
        .clamp(18.0, double.infinity);
  }
}
