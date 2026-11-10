import 'package:azkar/reminders/reminders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('nextInstance', () {
    final utc = tz.UTC;
    const six = TimeOfDay(hour: 6, minute: 0);

    test('later today', () {
      final now = tz.TZDateTime(utc, 2026, 5, 10, 5, 59);
      expect(nextInstance(now, six), tz.TZDateTime(utc, 2026, 5, 10, 6, 0));
    });

    test('exactly now or past -> tomorrow, across month/year end', () {
      expect(nextInstance(tz.TZDateTime(utc, 2026, 5, 10, 6, 0), six), tz.TZDateTime(utc, 2026, 5, 11, 6));
      expect(nextInstance(tz.TZDateTime(utc, 2026, 12, 31, 20), six), tz.TZDateTime(utc, 2027, 1, 1, 6));
    });

    test('keeps wall-clock time across a DST change', () {
      final ny = tz.getLocation('America/New_York');
      // DST starts 2026-03-08 in New York.
      final next = nextInstance(tz.TZDateTime(ny, 2026, 3, 7, 20), six);
      expect([next.day, next.hour, next.minute], [8, 6, 0]);
    });
  });

  test('prefs round-trip of enabled + time', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();

    expect(Reminder.morning.enabledIn(p), isFalse);
    expect(Reminder.morning.timeIn(p), const TimeOfDay(hour: 6, minute: 0));
    expect(Reminder.evening.timeIn(p), const TimeOfDay(hour: 17, minute: 0));

    await Reminder.evening.saveIn(p, on: true, time: const TimeOfDay(hour: 18, minute: 45));
    expect(Reminder.evening.enabledIn(p), isTrue);
    expect(Reminder.evening.timeIn(p), const TimeOfDay(hour: 18, minute: 45));
    expect(Reminder.morning.enabledIn(p), isFalse); // independent keys
  });
}
