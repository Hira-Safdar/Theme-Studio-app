import 'package:flutter_test/flutter_test.dart';
import 'package:theme_studio/main.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ThemeStudioApp());
    // Bottom navigation bar load hui ya nahi, isko confirm karta hai.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
