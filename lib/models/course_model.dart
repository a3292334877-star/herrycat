import 'package:flutter/material.dart';

/// 周类型：全部周、单周、双周
enum WeekCycle {
  all,   // 全部周
  odd,   // 单周
  even,  // 双周
}

/// 课程性质
enum CourseNature {
  required,  // 必修
  elective,  // 选修
  public,    // 公选
}

class Course {
  final String id;
  final String name;
  final String teacher;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String location;
  final Color color;
  final WeekCycle weekCycle;
  final CourseNature nature;     // 必修/选修/公选
  final double credits;          // 学分
  final String weekRange;        // 周数范围，如 "1-16周"

  Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.color,
    this.weekCycle = WeekCycle.all,
    this.nature = CourseNature.required,
    this.credits = 0.0,
    this.weekRange = '1-16周',
  });

  String get natureLabel {
    switch (nature) {
      case CourseNature.required:
        return '必修';
      case CourseNature.elective:
        return '选修';
      case CourseNature.public:
        return '公选';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'color': color.value,
      'weekCycle': weekCycle.index,
      'nature': nature.index,
      'credits': credits,
      'weekRange': weekRange,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      name: map['name'],
      teacher: map['teacher'] ?? '',
      dayOfWeek: map['dayOfWeek'],
      startTime: map['startTime'],
      endTime: map['endTime'],
      location: map['location'] ?? '',
      color: Color(map['color'] ?? 0xFF5B9BF5),
      weekCycle: WeekCycle.values[map['weekCycle'] ?? 0],
      nature: CourseNature.values[map['nature'] ?? 0],
      credits: (map['credits'] ?? 0.0).toDouble(),
      weekRange: map['weekRange'] ?? '1-16周',
    );
  }

  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? location,
    Color? color,
    WeekCycle? weekCycle,
    CourseNature? nature,
    double? credits,
    String? weekRange,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      color: color ?? this.color,
      weekCycle: weekCycle ?? this.weekCycle,
      nature: nature ?? this.nature,
      credits: credits ?? this.credits,
      weekRange: weekRange ?? this.weekRange,
    );
  }

  String get dayName {
    const days = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return days[dayOfWeek];
  }

  String get timeSlot => '$startTime - $endTime';

  String get weekCycleLabel {
    switch (weekCycle) {
      case WeekCycle.all:
        return '全周';
      case WeekCycle.odd:
        return '单周';
      case WeekCycle.even:
        return '双周';
    }
  }

  /// 判断某周次（从1开始）是否应该显示这门课
  bool shouldShowInWeek(int weekNum) {
    if (weekCycle == WeekCycle.all) return true;
    if (weekCycle == WeekCycle.odd) return weekNum % 2 == 1;
    if (weekCycle == WeekCycle.even) return weekNum % 2 == 0;
    return true;
  }
}
