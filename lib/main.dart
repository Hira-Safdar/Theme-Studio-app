import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/wallpaper_screen.dart';
import 'screens/icon_changer_screen.dart';
import 'screens/widgets_screen.dart';
import 'screens/control_center_screen.dart';

void main() {
  runApp(const ThemeStudioApp());
}

class ThemeStudioApp extends StatelessWidget {
  const ThemeStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Theme Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00FFF0),
      ),
      home: const RootShell(),
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
