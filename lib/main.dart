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
  runApp(HenrycatApp(settingsProvider: settingsProvider));
}

class HenrycatApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const HenrycatApp({super.key, required this.settingsProvider});

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
            title: 'Henrycat',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF1C1E21),
              colorScheme: ColorScheme.dark(
                primary: const Color(0xFF5B9BF5),
                secondary: const Color(0xFFFF7B9C),
                surface: const Color(0xFF2C2E33),
                onSurface: Colors.white,
                onPrimary: Colors.white,
              ),
              cardTheme: CardTheme(
                color: const Color(0xFF2C2E33),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1C1E21),
                foregroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFF5B9BF5),
                foregroundColor: Colors.white,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF2C2E33),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF5B9BF5), width: 1.5),
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                backgroundColor: const Color(0xFF2C2E33),
                contentTextStyle: const TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                behavior: SnackBarBehavior.floating,
              ),
              dialogTheme: DialogTheme(
                backgroundColor: const Color(0xFF2C2E33),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF5B9BF5);
                  }
                  return Colors.grey;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF5B9BF5).withOpacity(0.5);
                  }
                  return Colors.grey.withOpacity(0.3);
                }),
              ),
              tabBarTheme: TabBarTheme(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[500],
                indicatorColor: const Color(0xFF5B9BF5),
                dividerColor: Colors.transparent,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF1C1E21),
              colorScheme: ColorScheme.dark(
                primary: const Color(0xFF5B9BF5),
                secondary: const Color(0xFFFF7B9C),
                surface: const Color(0xFF2C2E33),
                onSurface: Colors.white,
                onPrimary: Colors.white,
              ),
              cardTheme: CardTheme(
                color: const Color(0xFF2C2E33),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1C1E21),
                foregroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: Color(0xFF5B9BF5),
                foregroundColor: Colors.white,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF2C2E33),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF5B9BF5), width: 1.5),
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                backgroundColor: const Color(0xFF2C2E33),
                contentTextStyle: const TextStyle(color: Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                behavior: SnackBarBehavior.floating,
              ),
              dialogTheme: DialogTheme(
                backgroundColor: const Color(0xFF2C2E33),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
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
