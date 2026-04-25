import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_model.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';

class CourseProvider extends ChangeNotifier {
  List<Course> _courses = [];
  bool _isLoading = false;
  Database? _db;
  final NotificationService _notificationService = NotificationService();

  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;

  List<Course> getCoursesForDay(int day) {
    return _courses.where((c) => c.dayOfWeek == day).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Future<void> _initDB() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'Henrycat.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE courses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            teacher TEXT,
            dayOfWeek INTEGER NOT NULL,
            startTime TEXT NOT NULL,
            endTime TEXT NOT NULL,
            location TEXT,
            color INTEGER NOT NULL,
            isRecurring INTEGER DEFAULT 1
          )
        ''');
      },
    );
  }

  Future<int> _getReminderMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('reminder_minutes') ?? 15;
  }

  Future<void> loadCourses() async {
    _isLoading = true;
    notifyListeners();

    await _initDB();
    await _notificationService.initialize();
    final maps = await _db!.query('courses');
    _courses = maps.map((m) => Course.fromMap(m)).toList();

    final reminderMinutes = await _getReminderMinutes();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifications_enabled') ?? true) {
      await _notificationService.rescheduleAllCourses(_courses, reminderMinutes);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCourse(Course course) async {
    await _initDB();
    await _db!.insert('courses', course.toMap());
    _courses.add(course);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifications_enabled') ?? true) {
      final reminderMinutes = await _getReminderMinutes();
      await _notificationService.scheduleCourseNotification(course, reminderMinutes);
    }
    notifyListeners();
  }

  Future<void> updateCourse(Course course) async {
    await _initDB();
    await _db!.update(
      'courses',
      course.toMap(),
      where: 'id = ?',
      whereArgs: [course.id],
    );
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index != -1) {
      _courses[index] = course;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notifications_enabled') ?? true) {
        await _notificationService.cancelNotification(course.id);
        final reminderMinutes = await _getReminderMinutes();
        await _notificationService.scheduleCourseNotification(course, reminderMinutes);
      }
      notifyListeners();
    }
  }

  Future<void> deleteCourse(String id) async {
    await _initDB();
    await _db!.delete('courses', where: 'id = ?', whereArgs: [id]);
    _courses.removeWhere((c) => c.id == id);
    await _notificationService.cancelNotification(id);
    notifyListeners();
  }

  Future<void> swapCourses(String courseId1, String courseId2) async {
    final course1 = _courses.firstWhere((c) => c.id == courseId1);
    final course2 = _courses.firstWhere((c) => c.id == courseId2);

    final tempDay = course1.dayOfWeek;
    final tempStart = course1.startTime;
    final tempEnd = course1.endTime;

    await updateCourse(course1.copyWith(
      dayOfWeek: course2.dayOfWeek,
      startTime: course2.startTime,
      endTime: course2.endTime,
    ));

    await updateCourse(course2.copyWith(
      dayOfWeek: tempDay,
      startTime: tempStart,
      endTime: tempEnd,
    ));
  }
}