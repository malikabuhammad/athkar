import 'package:adhan/adhan.dart';
import 'package:azkar/core/settings.dart';
import 'package:azkar/prayer/prayer_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Makkah, 2026-03-15, Muslim World League.
  final day = DateTime(2026, 3, 15);
  List<DateTime> times([Madhab m = Madhab.shafi]) =>
      dayTimes(21.4225, 39.8262, day, CalculationMethod.muslim_world_league, m);

  test('six times are strictly increasing', () {
    final t = times();
    expect(t, hasLength(6));
    for (var i = 1; i < 6; i++) {
      expect(t[i].isAfter(t[i - 1]), isTrue, reason: 'index $i');
    }
  });

  test('Hanafi Asr is later than Shafi Asr', () {
    expect(times(Madhab.hanafi)[3].isAfter(times()[3]), isTrue);
  });

  test('next prayer selection', () {
    final t = times();
    const m = Duration(minutes: 1);
    expect(nextIndex(t, t[0].subtract(m)), 0); // before Fajr
    expect(nextIndex(t, t[0]), 1); // exactly at Fajr -> Sunrise
    expect(nextIndex(t, t[2].add(m)), 3); // after Dhuhr -> Asr
    expect(nextIndex(t, t[4].add(m)), 5); // after Maghrib -> Isha
    expect(nextIndex(t, t[5].add(m)), 6); // after Isha -> tomorrow's Fajr
  });

  test('time remaining formatting', () {
    Settings.I.locale = 'en';
    expect(formatRemaining(const Duration(hours: 1, minutes: 5, seconds: 30)), '1h 6m');
    expect(formatRemaining(const Duration(seconds: 30)), '1m');
    expect(formatRemaining(const Duration(minutes: 45)), '45m');
    expect(formatRemaining(const Duration(hours: 2)), '2h 0m');
    Settings.I.locale = 'ar';
    expect(formatRemaining(const Duration(hours: 2, minutes: 3)), '2 س 3 د');
  });
}
