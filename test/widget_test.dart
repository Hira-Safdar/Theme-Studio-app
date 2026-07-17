import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theme_studio/main.dart';

void main() {
  testWidgets('App loads through splash and shows bottom navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ThemeStudioApp());

    // Splash's init delay is 900ms — advance past it in one jump so it
    // navigates to /home, then pump once more (no time advance) to let
    // the new route finish building.
    //
    // We deliberately avoid pumpAndSettle() here: WidgetsScreen starts a
    // 1-second repeating Timer for its live clock preview as soon as it
    // mounts (all 5 tabs mount immediately via IndexedStack), and that
    // Timer schedules a new frame every second forever — pumpAndSettle()
    // would wait for "no more frames scheduled" and hang indefinitely.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
