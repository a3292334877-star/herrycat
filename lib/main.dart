import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/course_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/add_course_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/import_schedule_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();
  runApp(HerrycatApp(settingsProvider: settingsProvider));
}

class HerrycatApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const HerrycatApp({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => CourseProvider()..loadCourses()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Herrycat',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            darkTheme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
            ),
            themeMode: settings.themeMode,
            home: const HomeScreen(),
            routes: {
              '/add': (context) => const AddCourseScreen(),
              '/detail': (context) => const CourseDetailScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/statistics': (context) => const StatisticsScreen(),
              '/import': (context) => const ImportScheduleScreen(),
            },
          );
        },
      ),
    );
  }
}