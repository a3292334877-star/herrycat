import 'package:flutter/material.dart';

class Course {
  final String id;
  final String name;
  final String teacher;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String location;
  final Color color;
  final bool isRecurring;

  Course({
    required this.id,
    required this.name,
    required this.teacher,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.color,
    this.isRecurring = true,
  });

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
      'isRecurring': isRecurring ? 1 : 0,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      name: map['name'],
      teacher: map['teacher'],
      dayOfWeek: map['dayOfWeek'],
      startTime: map['startTime'],
      endTime: map['endTime'],
      location: map['location'],
      color: Color(map['color']),
      isRecurring: (map['isRecurring'] ?? 1) == 1,
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
    bool? isRecurring,
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
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  String get dayName {
    const days = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return days[dayOfWeek];
  }

  String get timeSlot => '$startTime - $endTime';
}