import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/wallpaper_screen.dart';
import 'screens/icon_changer_screen.dart';
import 'screens/widgets_screen.dart';
import 'screens/control_center_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notes_editor_screen.dart';
import 'screens/weather_location_screen.dart';
import 'services/app_strings.dart';
import 'services/download_service.dart';
import 'services/favorites_service.dart';
import 'services/locale_controller.dart';
import 'services/native_bridge_service.dart';
import 'services/theme_mode_controller.dart';
import 'services/wallpaper_favorites_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ThemeStudioApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

class ThemeStudioApp extends StatefulWidget {
  const ThemeStudioApp({super.key});

  @override
  State<ThemeStudioApp> createState() => _ThemeStudioAppState();
}

class _ThemeStudioAppState extends State<ThemeStudioApp> {
  @override
  void initState() {
    super.initState();
    LocaleController.instance.load();
    ThemeModeController.instance.load();
    FavoritesService.instance.load();
    WallpaperFavoritesService.instance.load();
    DownloadService.instance.load();

    NativeBridgeService.instance.setIncomingCallHandler((method) async {
      if (method == 'openNotesEditor') {
        navigatorKey.currentState?.pushNamed('/notes_editor');
      }
      // Weather widget tap (warm start, app already chal rahi ho) -- Notes
      // ke fallback-editor jaisa hi pattern, bas yahan har baar chalta hai
      // (fallback-only nahi) kyunke widget tap ka poora point hi location
      // choose/change karna hai.
      if (method == 'openWeatherLocation') {
        navigatorKey.currentState?.pushNamed('/weather_location');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([LocaleController.instance, ThemeModeController.instance]),
      builder: (context, _) {
        final themeMode = ThemeModeController.instance.themeMode;
        return MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.lightThemeData,
          darkTheme: AppTheme.darkThemeData,
          themeMode: themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/home': (context) => const RootShell(),
            '/settings': (context) => const SettingsScreen(),
            '/notes_editor': (context) => const NotesEditorScreen(),
            '/weather_location': (context) => const WeatherLocationScreen(),
          },
        );
      },
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    WallpaperScreen(),
    IconChangerScreen(),
    WidgetsScreen(),
    ControlCenterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home), label: tr('nav_home')),
          NavigationDestination(icon: const Icon(Icons.wallpaper), label: tr('nav_wallpaper')),
          NavigationDestination(icon: const Icon(Icons.apps), label: tr('nav_icons')),
          NavigationDestination(icon: const Icon(Icons.widgets), label: tr('nav_widgets')),
          NavigationDestination(icon: const Icon(Icons.tune), label: tr('nav_control')),
        ],
      ),
    );
  }
}