import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../models/course_model.dart';

/// Weekly grid view with period-based timeline (深职大作息)
class WeeklyGridView extends StatelessWidget {
  const WeeklyGridView({super.key});

  static const int _p12s = 8 * 60 + 30;
  static const int _p12e = 10 * 60 + 5;
  static const int _p34s = 10 * 60 + 25;
  static const int _p34e = 12 * 60;
  static const int _p56s = 14 * 60;
  static const int _p56e = 15 * 60 + 35;
  static const int _p78s = 15 * 60 + 45;
  static const int _p78e = 17 * 60 + 20;
  static const int _p910s = 17 * 60 + 30;
  static const int _p910e = 19 * 60 + 5;

  static const int _lunchStart = 12 * 60;
  static const int _lunchEnd = 14 * 60;

  static const double _lunchGap = 22.0;
  static const double _timeColW = 68.0;

  static double _minToAmY(int min, double pxPerMin) => (min - _p12s) * pxPerMin;
  static double _minToPmY(int min, double pxPerMin, double amH) =>
      amH + _lunchGap + (min - _p56s) * pxPerMin;
  static double _periodH(int pStart, int pEnd, double pxPerMin) =>
      (pEnd - pStart) * pxPerMin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<CourseProvider, SettingsProvider>(
      builder: (context, courseProvider, settings, child) {
        if (courseProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final weekNum = settings.currentWeek;
        final courses = courseProvider.courses;
        const dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

        return Column(
          children: [
            _buildWeekBar(context, settings, weekNum, isDark),
            _buildHeader(dayNames, isDark),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableH = constraints.maxHeight;
                  const amMinSpan = _p34e - _p12s;
                  const pmMinSpan = _p910e - _p56s;
                  const lunchMin = _lunchGap / 0.72;
                  final totalMin = amMinSpan + lunchMin.round() + pmMinSpan;
                  final pxPerMin = availableH / totalMin;
                  final amH = amMinSpan * pxPerMin;
                  final totalH = availableH;
                  final colW = (constraints.maxWidth - _timeColW) / 7.0;

                  return Column(
                    children: [
                      Expanded(
                        child: _buildGrid(courses, weekNum, colW, pxPerMin, amH, totalH, isDark),
                      ),
                      _MemoStrip(courseProvider: courseProvider, isDark: isDark),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Helpers for theme-aware colors ──
  Color _bg(bool isDark) => isDark ? const Color(0xFF1C1E21) : Colors.white;
  Color _surface(bool isDark) => isDark ? const Color(0xFF2C2E33) : const Color(0xFFF0F0F0);
  Color _textMain(bool isDark) => isDark ? Colors.white : Colors.black87;
  Color _textSec(bool isDark) => isDark ? Colors.grey : Colors.grey[600]!;
  Color _divider(bool isDark) => isDark ? Colors.grey[800]! : Colors.grey[300]!;

  Widget _buildWeekBar(BuildContext context, SettingsProvider settings, int weekNum, bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: _bg(isDark),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: _textMain(isDark)),
            onPressed: () {
              if (settings.currentWeek > 1) settings.setCurrentWeek(settings.currentWeek - 1);
            },
          ),
          GestureDetector(
            onTap: () => _showWeekPicker(context, settings, weekNum, isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _surface(isDark),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, color: _textMain(isDark), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '第 $weekNum 周',
                    style: TextStyle(color: _textMain(isDark), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: _textMain(isDark)),
            onPressed: () {
              if (settings.currentWeek < 20) settings.setCurrentWeek(settings.currentWeek + 1);
            },
          ),
        ],
      ),
    );
  }

  void _showWeekPicker(BuildContext context, SettingsProvider settings, int current, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface(isDark),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择周次', style: TextStyle(color: _textMain(isDark), fontSize: 16)),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.6,
                ),
                itemCount: 20,
                itemBuilder: (ctx, i) {
                  final w = i + 1;
                  final isSelected = w == current;
                  return InkWell(
                    onTap: () { settings.setCurrentWeek(w); Navigator.pop(ctx); },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF5B9BF5) : (isDark ? const Color(0xFF3A3D41) : Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '$w',
                          style: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
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

  Widget _buildHeader(List<String> dayNames, bool isDark) {
    return SizedBox(
      height: 26,
      child: Row(
        children: [
          const SizedBox(width: _timeColW, height: 26),
          ...List.generate(7, (i) => Expanded(
            child: Center(
              child: Text(dayNames[i], style: TextStyle(color: _textSec(isDark), fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Course> courses, int weekNum, double colW, double pxPerMin, double amH, double totalH, bool isDark) {
    return SingleChildScrollView(
      child: SizedBox(
        height: totalH,
        child: Row(
          children: [
            // Left: period time axis
            SizedBox(
              width: _timeColW,
              height: totalH,
              child: Stack(
                children: [
                  _buildPeriodLabel(0, '1-2', '08:30\n10:05', isDark),
                  _buildPeriodLabel(_minToAmY(_p34s, pxPerMin), '3-4', '10:25\n12:00', isDark),
                  Positioned(
                    top: _minToAmY(_lunchStart, pxPerMin) + 3,
                    left: 0, right: 0,
                    child: Text('🌙', style: TextStyle(fontSize: 9, color: _textSec(isDark)), textAlign: TextAlign.center),
                  ),
                  _buildPeriodLabel(_minToPmY(_p56s, pxPerMin, amH), '5-6', '14:00\n15:35', isDark),
                  _buildPeriodLabel(_minToPmY(_p78s, pxPerMin, amH), '7-8', '15:45\n17:20', isDark),
                  _buildPeriodLabel(_minToPmY(_p910s, pxPerMin, amH), '9-10', '17:30\n19:05', isDark),
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
                height: totalH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildDivider(_minToAmY(_p12s, pxPerMin) + _periodH(_p12s, _p12e, pxPerMin), isDark),
                    _buildDivider(_minToAmY(_p34s, pxPerMin) + _periodH(_p34s, _p34e, pxPerMin), isDark),
                    Positioned(
                      top: _minToAmY(_lunchStart, pxPerMin),
                      height: _lunchGap,
                      left: 0, right: 0,
                      child: Column(
                        children: [
                          Container(height: 0.5, color: _divider(isDark).withOpacity(0.35)),
                          Expanded(child: Center(child: Text('午休', style: TextStyle(fontSize: 7, color: _textSec(isDark))))),
                          Container(height: 0.5, color: _divider(isDark).withOpacity(0.35)),
                        ],
                      ),
                    ),
                    _buildDivider(_minToPmY(_p56s, pxPerMin, amH) + _periodH(_p56s, _p56e, pxPerMin), isDark),
                    _buildDivider(_minToPmY(_p78s, pxPerMin, amH) + _periodH(_p78s, _p78e, pxPerMin), isDark),
                    ...dayCourses.map((c) => _CourseBlock(
                      course: c, colW: colW, totalH: totalH,
                      pxPerMin: pxPerMin, amH: amH,
                    )),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(double top, bool isDark) {
    return Positioned(
      top: top - 0.5,
      left: 0, right: 0,
      child: Container(height: 0.5, color: _divider(isDark).withOpacity(0.5)),
    );
  }

  Widget _buildPeriodLabel(double top, String period, String time, bool isDark) {
    return Positioned(
      top: top,
      left: 0, right: 0,
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(period, style: TextStyle(color: _textMain(isDark), fontSize: 10, fontWeight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 2),
            Text(time, textAlign: TextAlign.center, style: TextStyle(color: _textSec(isDark), fontSize: 7, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

// ── Bottom memo strip ──
class _MemoStrip extends StatelessWidget {
  final CourseProvider courseProvider;
  final bool isDark;

  const _MemoStrip({required this.courseProvider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final events = _buildCountdownEvents();
    if (events.isEmpty) return const SizedBox.shrink();

    final bg = isDark ? const Color(0xFF1C1E21) : Colors.white;
    final border = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border.withOpacity(0.3), width: 0.5)),
      ),
      child: Row(
        children: events.map((e) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: _MemoCard(event: e, isDark: isDark),
          ),
        )).toList(),
      ),
    );
  }

  List<_CountdownEvent> _buildCountdownEvents() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    final events = <_CountdownEvent>[];
    const dayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    for (int offset = 1; offset <= 6; offset++) {
      final checkDay = dayOfWeek + offset;
      if (checkDay > 7) continue;
      final dayCourses = courseProvider.getCoursesForDay(checkDay);
      if (dayCourses.isEmpty) continue;

      final label = offset == 1 ? '明天' : dayNames[checkDay];

      events.add(_CountdownEvent(
        label: label,
        subtitle: '${dayCourses.length}节课',
        daysLeft: offset,
        icon: Icons.school,
        color: const Color(0xFF5B9BF5),
      ));
    }

    return events;
  }
}

class _CountdownEvent {
  final String label;
  final String subtitle;
  final int daysLeft;
  final IconData icon;
  final Color color;

  _CountdownEvent({
    required this.label,
    required this.subtitle,
    required this.daysLeft,
    required this.icon,
    required this.color,
  });
}

class _MemoCard extends StatelessWidget {
  final _CountdownEvent event;
  final bool isDark;

  const _MemoCard({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF2C2E33) : Colors.white;
    final textMain = isDark ? Colors.white : Colors.black87;
    final textSec = isDark ? Colors.grey[500]! : Colors.grey[600]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: event.color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(event.icon, size: 11, color: event.color),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  event.label,
                  style: TextStyle(color: event.color, fontSize: 10, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${event.daysLeft}天后',
              style: TextStyle(color: textMain, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            event.subtitle,
            style: TextStyle(color: textSec, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Course block ──
class _CourseBlock extends StatelessWidget {
  final Course course;
  final double colW;
  final double totalH;
  final double pxPerMin;
  final double amH;

  const _CourseBlock({
    required this.course,
    required this.colW,
    required this.totalH,
    required this.pxPerMin,
    required this.amH,
  });

  @override
  Widget build(BuildContext context) {
    final startMin = _startMin();
    final endMin = _endMin();
    final topPx = _topPx(startMin);
    final heightPx = _heightPx(startMin, endMin);
    const cardRadius = 10.0;
    final cardW = colW * 0.95;
    final cardLeft = (colW - cardW) / 2;

    return Positioned(
      top: topPx,
      left: cardLeft,
      width: cardW,
      height: heightPx,
      child: Container(
        decoration: BoxDecoration(
          color: course.color.withOpacity(0.92),
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  course.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, height: 1.2),
                ),
              ),
            ),
            if (course.location.isNotEmpty)
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    course.location,
                    style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 11, height: 1.2),
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Tag(course.natureLabel, _tagColor(course.nature)),
                    const SizedBox(width: 4),
                    if (course.credits > 0) _Tag('${course.credits}学分', Colors.white38),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  course.weekRange,
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10, height: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tagColor(CourseNature nature) {
    switch (nature) {
      case CourseNature.required: return const Color(0xFFFF7B9C);
      case CourseNature.elective:  return const Color(0xFF5B9BF5);
      case CourseNature.public:    return const Color(0xFF6FCF97);
    }
  }

  int _startMin() {
    final p = course.startTime.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  int _endMin() {
    final p = course.endTime.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  double _topPx(int startMin) {
    if (startMin >= WeeklyGridView._lunchEnd) {
      return WeeklyGridView._minToPmY(startMin, pxPerMin, amH);
    }
    return WeeklyGridView._minToAmY(startMin, pxPerMin);
  }

  double _heightPx(int startMin, int endMin) {
    double h;
    if (endMin <= WeeklyGridView._lunchStart) {
      h = _dur(startMin, endMin) * pxPerMin;
    } else if (startMin >= WeeklyGridView._lunchEnd) {
      h = _dur(startMin, endMin) * pxPerMin;
    } else {
      // Crosses lunch break: AM minutes + lunch gap (pixels) + PM minutes
      h = (_dur(startMin, WeeklyGridView._lunchStart) +
           _dur(WeeklyGridView._lunchEnd, endMin)) *
          pxPerMin +
          WeeklyGridView._lunchGap;
    }
    return h.clamp(24.0, double.infinity);
  }

  int _dur(int s, int e) => e - s;
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}
