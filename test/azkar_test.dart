import 'package:azkar/azkar/azkar_data.dart';
import 'package:azkar/azkar/dhikr_list.dart';
import 'package:azkar/core/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Placeholder text only; real dhikr text comes solely from assets/azkar.json.
const fixture = '''
{"version":2,"categories":[
 {"id":"c1","ar":"قسم تجريبي","en":"Test category","items":[
  {"id":"t1","ar":"ذِكْرٌ تَجْرِيبِيٌّ أَوَّلُ","en":"Placeholder One","count":3,"book":"bukhari","number":1,"note_ar":"ملاحظة","extra":true},
  {"id":"t2","ar":"ذكر تجريبي ٢"},
  {"en":"no arabic, skipped"}
 ]},
 {"id":"empty","ar":"فارغ","en":"Empty","items":[]},
 "garbage"
]}
''';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Settings.I.load();
  });

  test('parses fixture defensively', () {
    final cats = parseAzkar(fixture);
    expect(cats, hasLength(1));
    final items = cats.single.items;
    expect(items.map((d) => d.id), ['t1', 't2']);
    expect(items[0].count, 3);
    expect(items[0].number, 1);
    expect(items[0].noteEn, isNull);
    expect(items[1].count, 1);
    expect(items[1].en, isNull);
    expect(parseAzkar('{}'), isEmpty);
  });

  test('search ignores diacritics and alef forms, English case-insensitive', () {
    final items = parseAzkar(fixture).single.items;
    expect(normalizeAr('أَإِآ'), 'ااا');
    expect(searchAzkar(items, 'تجريبي اول').map((d) => d.id), ['t1']);
    expect(searchAzkar(items, 'تجريبي').map((d) => d.id), ['t1', 't2']);
    expect(searchAzkar(items, 'PLACEHOLDER').map((d) => d.id), ['t1']);
    expect(searchAzkar(items, '  '), isEmpty);
  });

  testWidgets('counter stops at count and marks done', (tester) async {
    final d = parseAzkar(fixture).single.items.first;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DhikrList(items: [d]))));
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
    }
    expect(progressOf(d).value, 3);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    resetProgress([d]);
    await tester.pump();
    expect(find.text('0/3'), findsOneWidget);
  });

  test('favorite toggle persists', () {
    Favorites.toggle('t1');
    expect(Favorites.notifier.value, {'t1'});
    expect(Settings.I.prefs.getStringList('azkar_favs'), ['t1']);
    Favorites.toggle('t1');
    expect(Settings.I.prefs.getStringList('azkar_favs'), isEmpty);
  });
}
