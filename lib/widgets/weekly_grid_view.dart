import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../models/course_model.dart';

/// Weekly grid view with period-based timeline (深职大作息)
/// Left axis: 节次 (1-2/3-4/5-6/7-8/9-10) + 具体起止时间
/// Lunch break (12:00-14:00) shown as a subtle transparent gap
class WeeklyGridView extends StatelessWidget {
  const WeeklyGridView({super.key});

  // ===== 深职大作息参数 =====
  // 第1-2节: 08:30-10:05
  // 第3-4节: 10:25-12:00
  // 午休断层: 12:00-14:00（不排课，视觉收缩）
  // 第5-6节: 14:00-15:35
  // 第7-8节: 15:45-17:20
  // 第9-10节: 17:30-19:05

  static const int _p12s = 8 * 60 + 30; // 510
  static const int _p12e = 10 * 60 + 5;  // 605
  static const int _p34s = 10 * 60 + 25; // 625
  static const int _p34e = 12 * 60;       // 720
  static const int _p56s = 14 * 60;      // 840
  static const int _p56e = 15 * 60 + 35;  // 935
  static const int _p78s = 15 * 60 + 45;  // 945
  static const int _p78e = 17 * 60 + 20;  // 1040
  static const int _p910s = 17 * 60 + 30; // 1050
  static const int _p910e = 19 * 60 + 5;  // 1145

  static const int _lunchStart = 12 * 60; // 720
  static const int _lunchEnd   = 14 * 60; // 840

  // 每分钟像素（撑满节次区间）
  static const double _pxPerMin   = 0.72;
  static const double _lunchGap   = 22.0;
  static const double _timeColW   = 68.0;
  static const double _cardMargin = 2.0;   // 卡片外边距（缝隙）
  static const double _cardPad    = 4.0;   // 卡片内边距 4px
  static const double _cardRadius = 8.0;   // 圆角矩形 8px（不是胶囊）

  static double get _amHeight => (_p34e - _p12s) * _pxPerMin;
  static double get _pmHeight => (_p910e - _p56s) * _pxPerMin;

  static double _minToAmY(int min) => (min - _p12s) * _pxPerMin;
  static double _minToPmY(int min) => _amHeight + _lunchGap + (min - _p56s) * _pxPerMin;

  static int _dur(int s, int e) => e - s;

  @override
  Widget build(BuildContext context) {
    return Consumer2<CourseProvider, SettingsProvider>(
      builder: (context, courseProvider, settings, child) {
        if (courseProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final weekNum  = settings.currentWeek;
        final courses  = courseProvider.courses;
        const dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

        return LayoutBuilder(
          builder: (context, constraints) {
            // 均分7天列，精确等宽
            final colW = (constraints.maxWidth - _timeColW) / 7.0;

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
      height: 26,
      child: Row(
        children: [
          SizedBox(width: _timeColW, height: 26),
          ...List.generate(7, (i) => SizedBox(
            width: colW,
            height: 26,
            child: Center(child: Text(dayNames[i], style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w600))),
          )),
        ],
      ),
    );
  }

  // ===== 主网格 =====
  Widget _buildGrid(List<Course> courses, int weekNum, double colW) {
    final totalH = _amHeight + _lunchGap + _pmHeight;

    return SingleChildScrollView(
      child: SizedBox(
        height: totalH,
        child: Row(
          children: [
            // ===== 左侧：节次时间刻度 =====
            SizedBox(
              width: _timeColW,
              height: totalH,
              child: Stack(
                children: [
                  _buildPeriodLabel(0, '1-2', '08:30\n10:05'),
                  _buildPeriodLabel(_minToAmY(_p34s), '3-4', '10:25\n12:00'),
                  // 午休月亮（淡淡的）
                  Positioned(
                    top: _minToAmY(_lunchStart) + 3,
                    left: 0, right: 0,
                    child: const Text('🌙', style: TextStyle(fontSize: 9), textAlign: TextAlign.center),
                  ),
                  _buildPeriodLabel(_minToPmY(_p56s), '5-6', '14:00\n15:35'),
                  _buildPeriodLabel(_minToPmY(_p78s), '7-8', '15:45\n17:20'),
                  _buildPeriodLabel(_minToPmY(_p910s), '9-10', '17:30\n19:05'),
                ],
              ),
            ),

            // ===== 7天课程列 =====
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
                    // 上午节次分隔线
                    _buildDivider(_minToAmY(_p12s) + _dur(_p12s, _p12e) * _pxPerMin, 0.25),
                    _buildDivider(_minToAmY(_p34s) + _dur(_p34s, _p34e) * _pxPerMin, 0.25),
                    // 午休区（透明，只留淡分隔线）
                    Positioned(
                      top: _minToAmY(_lunchStart),
                      height: _lunchGap,
                      left: 0, right: 0,
                      child: Column(
                        children: [
                          Container(height: 0.5, color: Colors.grey[800]!.withOpacity(0.35)),
                          Expanded(child: Center(child: Text('午休', style: TextStyle(fontSize: 7, color: Colors.grey[700])))),
                          Container(height: 0.5, color: Colors.grey[800]!.withOpacity(0.35)),
                        ],
                      ),
                    ),
                    // 下午节次分隔线
                    _buildDivider(_minToPmY(_p56s) + _dur(_p56s, _p56e) * _pxPerMin, 0.25),
                    _buildDivider(_minToPmY(_p78s) + _dur(_p78s, _p78e) * _pxPerMin, 0.25),
                    // 课程块（margin=2px，左右撑满列宽）
                    ...dayCourses.map((c) => _CourseBlock(
                      course: c,
                      colW: colW,
                      totalH: totalH,
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

  Widget _buildDivider(double top, double opacity) {
    return Positioned(
      top: top - 0.5,
      left: 0, right: 0,
      child: Container(height: 0.5, color: Colors.grey[850]!.withOpacity(opacity)),
    );
  }

  Widget _buildPeriodLabel(double top, String period, String time) {
    return Positioned(
      top: top,
      left: 0, right: 0,
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(period, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1.2)),
            const SizedBox(height: 2),
            Text(time, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 7, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

// ── Course block（填满节次 + 圆角8px + margin 2px + 左对齐三行） ────────────────
class _CourseBlock extends StatelessWidget {
  final Course course;
  final double colW;
  final double totalH;

  const _CourseBlock({required this.course, required this.colW, required this.totalH});

  @override
  Widget build(BuildContext context) {
    final startMin = _startMin();
    final endMin   = _endMin();
    final topPx    = _topPx(startMin);
    final heightPx = _heightPx(startMin, endMin);
    // 卡片宽度 = 列宽的95%，居中，两侧各留2.5%
    final cardW = colW * 0.95;
    final cardLeft = (colW - cardW) / 2;

    return Positioned(
      top: topPx,
      left: cardLeft,
      width: cardW,
      height: heightPx,
      child: Container(
        padding: const EdgeInsets.all(WeeklyGridView._cardPad),
        decoration: BoxDecoration(
          color: course.color.withOpacity(0.92),
          borderRadius: BorderRadius.circular(WeeklyGridView._cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,  // 强制左对齐
          children: [
            // 第1行：课程名（13px加粗，maxLines=2禁止换行到第三行）
            Text(
              course.name,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, height: 1.25),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (course.location.isNotEmpty) ...[
              const SizedBox(height: 2),
              // 第2行：地点（11px淡色）
              Text(
                course.location,
                style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 11, height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (course.teacher.isNotEmpty) ...[
              const SizedBox(height: 2),
              // 第3行：老师（11px淡色，前缀小图标）
              Text(
                course.teacher,
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11, height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
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
    if (startMin >= WeeklyGridView._p56s) return WeeklyGridView._minToPmY(startMin);
    return WeeklyGridView._minToAmY(startMin);
  }

  double _heightPx(int startMin, int endMin) {
    return (_dur(startMin, endMin) * WeeklyGridView._pxPerMin).clamp(24.0, double.infinity);
  }

  int _dur(int s, int e) => e - s;
}