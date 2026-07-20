import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/wallpaper_screen.dart';
import 'screens/icon_changer_screen.dart';
import 'screens/widgets_screen.dart';
import 'screens/control_center_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notes_editor_screen.dart';
import 'services/native_bridge_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ThemeStudioApp());
}

/// App ke andar kahin se bhi navigate karne ke liye -- Notes widget ka
/// "warm start" case (app already chal rahi ho) isi ke zariye
/// "/notes_editor" route push karta hai, kyunke us waqt koi BuildContext
/// seedha available nahi hota (native se aaya hua call hai).
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
    // Native (MainActivity.onNewIntent) se "openNotesEditor" call sunte
    // hain -- ye sirf tab aata hai jab Notes widget ka fallback-editor
    // tap ho aur app already background/foreground mein chal rahi ho.
    NativeBridgeService.instance.setIncomingCallHandler((method) async {
      if (method == 'openNotesEditor') {
        navigatorKey.currentState?.pushNamed('/notes_editor');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.themeData,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const RootShell(),
        '/settings': (context) => const SettingsScreen(),
        '/notes_editor': (context) => const NotesEditorScreen(),
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
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.wallpaper), label: 'Wallpaper'),
          NavigationDestination(icon: Icon(Icons.apps), label: 'Icons'),
          NavigationDestination(icon: Icon(Icons.widgets), label: 'Widgets'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Control'),
        ],
      ),
    );
  }
}