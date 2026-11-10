import 'package:azkar/tasbih/tasbih_tab.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('tap increments and target rollover counts rounds', () async {
    SharedPreferences.setMockInitialValues({});
    final c = TasbihCounter(await SharedPreferences.getInstance());
    expect(c.tap(), isFalse);
    expect(c.count.value, 1);
    for (var i = 1; i < 32; i++) {
      c.tap();
    }
    expect(c.tap(), isTrue); // 33rd tap completes the round
    expect(c.count.value, 33);
    expect(c.rounds.value, 1);
    c.tap();
    expect(c.count.value, 1);

    c.setTarget(0);
    for (var i = 0; i < 200; i++) {
      expect(c.tap(), isFalse);
    }
    expect(c.rounds.value, 1);
  });

  test('state restores from prefs', () async {
    SharedPreferences.setMockInitialValues({'tasbih_count': 7, 'tasbih_target': 100, 'tasbih_rounds': 2});
    final prefs = await SharedPreferences.getInstance();
    final c = TasbihCounter(prefs)..tap();
    expect([c.count.value, c.target.value, c.rounds.value], [8, 100, 2]);
    expect(TasbihCounter(prefs).count.value, 8);
  });
}
