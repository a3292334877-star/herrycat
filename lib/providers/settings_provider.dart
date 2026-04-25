import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyDarkMode = 'dark_mode';
  static const _keyNotifications = 'notifications_enabled';
  static const _keyReminderMinutes = 'reminder_minutes';

  bool _darkMode = false;
  bool _notificationsEnabled = true;
  int _reminderMinutes = 15;
  bool _loaded = false;

  bool get darkMode => _darkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  int get reminderMinutes => _reminderMinutes;
  bool get loaded => _loaded;

  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(_keyDarkMode) ?? false;
    _notificationsEnabled = prefs.getBool(_keyNotifications) ?? true;
    _reminderMinutes = prefs.getInt(_keyReminderMinutes) ?? 15;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
  }

  Future<void> setReminderMinutes(int value) async {
    _reminderMinutes = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderMinutes, value);
  }
}
