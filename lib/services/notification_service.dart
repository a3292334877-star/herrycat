import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/course_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  Future<void> scheduleCourseNotification(Course course, int reminderMinutes) async {
    await _notifications.zonedSchedule(
      course.id.hashCode,
      '📚 课程提醒',
      '${course.name} 将在 $reminderMinutes 分钟后开始\n地点: ${course.location.isEmpty ? "未设置" : course.location}',
      _nextInstanceOf(course.dayOfWeek, course.startTime, reminderMinutes),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'course_reminders',
          '课程提醒',
          channelDescription: '课程开始前的提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          color: course.color,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOf(int dayOfWeek, String startTime, int reminderMinutes) {
    final now = tz.TZDateTime.now(tz.local);
    final timeParts = startTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
        .subtract(Duration(minutes: reminderMinutes));

    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelNotification(String courseId) async {
    await _notifications.cancel(courseId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> rescheduleAllCourses(List<Course> courses, int reminderMinutes) async {
    await cancelAllNotifications();
    for (final course in courses) {
      await scheduleCourseNotification(course, reminderMinutes);
    }
  }
}