import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/course_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'screens/add_course_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'screens/import_schedule_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final courseProvider = CourseProvider();
  final settingsProvider = SettingsProvider();
  await courseProvider.init();
  await settingsProvider.init();
  runApp(HenrycatApp(
    courseProvider: courseProvider,
    settingsProvider: settingsProvider,
  ));
}

class HenrycatApp extends StatelessWidget {
  final CourseProvider courseProvider;
  final SettingsProvider settingsProvider;

  const HenrycatApp({
    super.key,
    required this.courseProvider,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: courseProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Henrycat',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: const Color(0xFF5B9BF5),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: const Color(0xFF5B9BF5),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
          ),
          home: const HomeScreen(),
          routes: {
            '/add': (_) => const AddCourseScreen(),
            '/settings': (_) => const SettingsScreen(),
            '/about': (_) => const AboutScreen(),
            '/import': (_) => const ImportScheduleScreen(),
          },
        ),
      ),
    );
  }
}
