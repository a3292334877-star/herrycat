import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../providers/course_provider.dart';

class CourseTable extends StatelessWidget {
  final CourseProvider provider;
  final int selectedWeek;
  final bool showWeekend;
  final ScrollController horizontalScroll;
  final ScrollController verticalScroll;
  final void Function(Course) onEdit;
  final void Function(Course, CourseProvider) onDelete;

  const CourseTable({
    super.key,
    required this.provider,
    required this.selectedWeek,
    required this.showWeekend,
    required this.horizontalScroll,
    required this.verticalScroll,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final days = showWeekend ? 7 : 5;
    const periods = 13;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayDow = DateTime.now().weekday;

    const cellW = 96.0;
    const cellH = 52.0;
    const headerH = 34.0;
    const labelW = 42.0;

    return Scrollbar(
      controller: horizontalScroll,
      child: SingleChildScrollView(
        controller: horizontalScroll,
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          controller: verticalScroll,
          child: Column(
            children: [
              SizedBox(
                height: headerH,
                child: Row(
                  children: [
                    const SizedBox(width: labelW),
                    for (int d = 1; d <= days; d++)
                      Container(
                        width: cellW,
                        height: headerH,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          border: Border(
                            right: BorderSide(
                                color: cs.outlineVariant, width: 0.5),
                          ),
                        ),
                        child: Text(
                          '周${Course.dayNames[d - 1]}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: todayDow == d ? cs.primary : cs.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (int pIdx = 0; pIdx < periods; pIdx++)
                SizedBox(
                  height: cellH,
                  child: Row(
                    children: [
                      Container(
                        width: labelW,
                        height: cellH,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: Border(
                            bottom: BorderSide(
                                color: cs.outlineVariant, width: 0.5),
                            right: BorderSide(
                                color: cs.outlineVariant, width: 0.5),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${pIdx + 1}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface),
                            ),
                            Text(
                              Course.periodLabels[pIdx],
                              style: TextStyle(
                                  fontSize: 9,
                                  color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      for (int d = 1; d <= days; d++)
                        CourseCell(
                          provider: provider,
                          day: d,
                          period: pIdx + 1,
                          selectedWeek: selectedWeek,
                          cellWidth: cellW,
                          cellHeight: cellH,
                          colorScheme: cs,
                          isDark: isDark,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CourseCell extends StatelessWidget {
  final CourseProvider provider;
  final int day;
  final int period;
  final int selectedWeek;
  final double cellWidth;
  final double cellHeight;
  final ColorScheme colorScheme;
  final bool isDark;
  final void Function(Course) onEdit;
  final void Function(Course, CourseProvider) onDelete;

  const CourseCell({
    super.key,
    required this.provider,
    required this.day,
    required this.period,
    required this.selectedWeek,
    required this.cellWidth,
    required this.cellHeight,
    required this.colorScheme,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final course = provider.courseAt(day, period);
    final showCourse = course != null &&
        period == course.startPeriod &&
        course.shouldShowInWeek(selectedWeek);

    if (showCourse) {
      final color =
          Color(Course.colors[course.colorIndex % Course.colors.length]);
      final spanH = cellHeight * course.duration;

      return SizedBox(
        width: cellWidth,
        height: cellHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 1,
              left: 1,
              right: 1,
              height: spanH - 2,
              child: GestureDetector(
                onTap: () => onEdit(course),
                onLongPress: () => onDelete(course, provider),
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border(
                      left: BorderSide(color: color, width: 3),
                    ),
                  ),
                  padding:
                      const EdgeInsets.only(left: 6, top: 3, right: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.fullName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (course.location.isNotEmpty)
                        Text(
                          course.location,
                          style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (course.teacher.isNotEmpty && course.duration >= 3)
                        Text(
                          course.teacher,
                          style: TextStyle(
                              fontSize: 9,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (course != null) {
      return SizedBox(width: cellWidth, height: cellHeight);
    }

    return Container(
      width: cellWidth,
      height: cellHeight,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5),
          bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5),
        ),
        color: (period > 5 && period <= 10)
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
            : null,
      ),
    );
  }
}
