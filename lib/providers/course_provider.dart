import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/course_model.dart';

class CourseProvider extends ChangeNotifier {
  List<Course> _courses = [];
  bool _isLoading = true;
  String? _error;
  Database? _db;

  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isReady => _db != null;

  Future<void> init() async {
    try {
      _db = await openDatabase(
        p.join(await getDatabasesPath(), 'herrycat.db'),
        version: 1,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE courses (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              teacher TEXT DEFAULT '',
              dayOfWeek INTEGER NOT NULL,
              startPeriod INTEGER NOT NULL,
              endPeriod INTEGER NOT NULL,
              location TEXT DEFAULT '',
              colorIndex INTEGER DEFAULT 0,
              weekCycle INTEGER DEFAULT 0,
              note TEXT DEFAULT ''
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // v1 -> v2: migrate schema here when adding new columns
          // if (oldVersion < 2) {
          //   await db.execute('ALTER TABLE courses ADD COLUMN credits REAL DEFAULT 0.0');
          // }
        },
      );
      await _loadCourses();
    } catch (e) {
      _error = '数据库初始化失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCourses() async {
    final db = _db;
    if (db == null) return;
    final rows = await db.query('courses', orderBy: 'dayOfWeek, startPeriod');
    _courses = rows.map(Course.fromMap).toList();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  List<Course> getCoursesForDay(int day) =>
      _courses.where((c) => c.dayOfWeek == day).toList();

  Map<int, List<Course>> get gridData {
    final map = <int, List<Course>>{};
    for (final c in _courses) {
      map.putIfAbsent(c.dayOfWeek, () => []).add(c);
    }
    return map;
  }

  Course? courseAt(int day, int period) {
    for (final c in _courses) {
      if (c.dayOfWeek == day &&
          period >= c.startPeriod &&
          period <= c.endPeriod) {
        return c;
      }
    }
    return null;
  }

  Future<void> addCourse(Course c) async {
    final db = _db;
    if (db == null) return;
    await db.insert('courses', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    await _loadCourses();
  }

  Future<void> batchInsertCourses(List<Course> courses) async {
    final db = _db;
    if (db == null) return;
    final batch = db.batch();
    for (final c in courses) {
      batch.insert('courses', c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await _loadCourses();
  }

  Future<void> updateCourse(Course c) async {
    final db = _db;
    if (db == null) return;
    await db.update('courses', c.toMap(),
        where: 'id = ?', whereArgs: [c.id]);
    await _loadCourses();
  }

  Future<void> deleteCourse(String id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
    await _loadCourses();
  }

  Future<void> clearAllCourses() async {
    final db = _db;
    if (db == null) return;
    await db.delete('courses');
    await _loadCourses();
  }

  Future<void> clearAllCoursesForImport() async {
    final db = _db;
    if (db == null) return;
    await db.delete('courses', where: 'id LIKE ?', whereArgs: ['imp_%']);
  }

  Future<void> loadCourses() => _loadCourses();
}
