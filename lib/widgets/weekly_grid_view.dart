import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../models/course_model.dart';

/// Weekly grid view with period-based timeline (深职大作息)
/// Left axis: 节次 (1-12) + 具体起止时间
/// Lunch break (12:00-14:00) shown as a collapsed visual gap
class WeeklyGridView extends StatelessWidget {
  const WeeklyGridView({super.key});

  // ===== 深职大作息参数 =====
  // 第1-2节: 08:30-10:05
  // 第3-4节: 10:25-12:00
  // 午休断层: 12:00-14:00（不排课，视觉收缩）
  // 第5-6节: 14:00-15:35
  // 第7-8节: 15:45-17:20
  // 第9-10节: 17:30-19:05

  // 每节课区间（分钟）
  static const int _p12s = 8 * 60 + 30; // 510
  static const int _p12e = 10 * 60 + 5; // 605
  static const int _p34s = 10 * 60 + 25; // 625
  static const int _p34e = 12 * 60;      // 720
  static const int _p56s = 14 * 60;      // 840
  static const int _p56e = 15 * 60 + 35;  // 935
  static const int _p78s = 15 * 60 + 45;  // 945
  static const int _p78e = 17 * 60 + 20;  // 1040
  static const int _p910s = 17 * 60 + 30; // 1050
  static const int _p910e = 19 * 60 + 5;  // 1145

  // 午餐断裂区（分钟）
  static const int _lunchStart = 12 * 60;     // 720
  static const int _lunchEnd   = 14 * 60;     // 840

  // 总垂直范围（分钟）：上午 + 午休gap(20px) + 下午
  static const int _amStart  = _p12s; // 510
  static const int _amEnd    = _p34e; // 720
  static const int _pmStart  = _p56s; // 840
  static const int _pmEnd    = _p910e; // 1145
  static const int _totalMin = (_pmEnd - _amStart); // 635 + lunch

  // 每节次基础高度 px/分钟
  static const double _pxPerMin = 0.55;
  static const double _lunchGap = 24.0; // 午休区视觉高度
  static const double _timeColW = 64.0;

  // 上午时间范围高度
  static double get _amHeight => (_amEnd - _amStart) * _pxPerMin;
  // 下午时间范围高度
  static double get _pmHeight => (_pmEnd - _pmStart) * _pxPerMin;

  // 分钟 → 上午区域 Y坐标
  static double _minToAmY(int min) =>
      (min - _amStart) * _pxPerMin;
  // 分钟 → 下午区域 Y坐标（午餐 gap 之后）
  static double _minToPmY(int min) =>
      _amHeight + _lunchGap + (min - _pmStart) * _pxPerMin;

  static double _courseHeight(int startMin, int endMin) {
    return (endMin - startMin) * _pxPerMin;
  }

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
            final colW = (constraints.maxWidth - _timeColW) / 7;

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
      height: 28,
      child: Row(
        children: [
          SizedBox(width: _timeColW, height: 28),
          ...List.generate(7, (i) => SizedBox(
            width: colW,
            height: 28,
            child: Center(child: Text(dayNames[i], style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w600))),
          )),
        ],
      ),
    );
  }

  // ===== 主网格：左侧节次刻度 + 7天列 =====
  Widget _buildGrid(List<Course> courses, int weekNum, double colW) {
    final totalH = _amHeight + _lunchGap + _pmHeight; // 整个网格高度

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
                  // 第1-2节
                  _buildPeriodLabel(0, '1-2', '08:30\n10:05'),
                  // 第3-4节
                  _buildPeriodLabel(_minToAmY(_p34s), '3-4', '10:25\n12:00'),
                  // 午休标记（左侧时间轴上显示）
                  Positioned(
                    top: _minToAmY(_lunchStart) + 2,
                    left: 4,
                    right: 4,
                    child: Text('🌙', style: const TextStyle(fontSize: 9), textAlign: TextAlign.center),
                  ),
                  // 第5-6节（下午）
                  _buildPeriodLabel(_minToPmY(_p56s), '5-6', '14:00\n15:35'),
                  // 第7-8节
                  _buildPeriodLabel(_minToPmY(_p78s), '7-8', '15:45\n17:20'),
                  // 第9-10节
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
                    // 午休分隔线（仅视觉引导）
                    Positioned(
                      top: _minToAmY(_lunchStart),
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 0.5,
                        color: Colors.grey[850]?.withOpacity(0.5),
                      ),
                    ),
                    // 上午分隔线（8:30 和 12:00 处）
                    Positioned(
                      top: _minToAmY(_p12s) + _courseHeight(_p12s, _p12e) - 0.5,
                      left: 0, right: 0,
                      child: Container(height: 0.5, color: Colors.grey[850]?.withOpacity(0.3)),
                    ),
                    Positioned(
                      top: _minToAmY(_p34s) + _courseHeight(_p34s, _p34e) - 0.5,
                      left: 0, right: 0,
                      child: Container(height: 0.5, color: Colors.grey[850]?.withOpacity(0.3)),
                    ),
                    // 下午分隔线
                    Positioned(
                      top: _minToPmY(_p56s) + _courseHeight(_p56s, _p56e) - 0.5,
                      left: 0, right: 0,
                      child: Container(height: 0.5, color: Colors.grey[850]?.withOpacity(0.3)),
                    ),
                    Positioned(
                      top: _minToPmY(_p78s) + _courseHeight(_p78s, _p78e) - 0.5,
                      left: 0, right: 0,
                      child: Container(height: 0.5, color: Colors.grey[850]?.withOpacity(0.3)),
                    ),
                    // 午休区（半透明淡色）
                    Positioned(
                      top: _minToAmY(_lunchStart),
                      height: _lunchGap,
                      left: 0, right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.015),
                          border: Border(
                            top: BorderSide(color: Colors.grey[800]!.withOpacity(0.3), width: 0.5),
                            bottom: BorderSide(color: Colors.grey[800]!.withOpacity(0.3), width: 0.5),
                          ),
                        ),
                        child: Center(
                          child: Text('午休', style: TextStyle(fontSize: 7, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                    // 课程块
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

  Widget _buildPeriodLabel(double top, String period, String time) {
    return Positioned(
      top: top,
      left: 0, right: 0,
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              period,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1.2),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 7, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Course block（填满节次区间 + 大圆角卡片） ────────────────────────────────
class _CourseBlock extends StatelessWidget {
  final Course course;
  final double colW;
  final double totalH;

  const _CourseBlock({required this.course, required this.colW, required this.totalH});

  @override
  Widget build(BuildContext context) {
    final topPx    = _topPx();
    final heightPx = _heightPx();

    // 判断属于哪个时段
    final parts = course.startTime.split(':');
    final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final isPM = startMin >= WeeklyGridView._pmStart;

    return Positioned(
      top: topPx,
      left: 2,
      right: 2,
      height: heightPx,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: course.color.withOpacity(0.90),
          borderRadius: BorderRadius.circular(8),
          border: isPM
              ? null
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              course.name,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (course.teacher.isNotEmpty && heightPx > 36) ...[
              const SizedBox(height: 1),
              Text(
                '👨‍🏫 ${course.teacher}',
                style: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 7),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (course.location.isNotEmpty && heightPx > 50) ...[
              const SizedBox(height: 1),
              Text(
                '📍 ${course.location}',
                style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 7),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _topPx() {
    final parts = course.startTime.split(':');
    final startMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    final endParts = course.endTime.split(':');
    final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    if (startMin >= WeeklyGridView._pmStart) {
      return WeeklyGridView._minToPmY(startMin);
    } else {
      // 上午含午休：startMin 在 510-720 之间
      return WeeklyGridView._minToAmY(startMin);
    }
  }

  double _heightPx() {
    final sp = course.startTime.split(':');
    final ep = course.endTime.split(':');
    final startMin = int.parse(sp[0]) * 60 + int.parse(sp[1]);
    final endMin   = int.parse(ep[0]) * 60 + int.parse(ep[1]);
    final durMin   = endMin - startMin;
    return (durMin * WeeklyGridView._pxPerMin).clamp(18.0, double.infinity);
  }
}