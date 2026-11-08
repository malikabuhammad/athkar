import 'package:azkar/core/settings.dart';
import 'package:azkar/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows 4 tabs and switches language', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Settings.I.load();
    await tester.pumpWidget(const App());
    // The azkar tab shows a spinner while its isolate load is pending, so
    // pumpAndSettle would never settle; pump past the route animations.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('القرآن'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle();
    await tester.tap(find.text('English'));
    await settle();
    await tester.pageBack();
    await settle();

    expect(find.text('Quran'), findsOneWidget);
    expect(find.text('القرآن'), findsNothing);
  });
}
