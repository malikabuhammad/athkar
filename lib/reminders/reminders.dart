import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:shared_preferences/shared_preferences.dart';
// Deferred so the ~2 MB tz database never lands in the web bundle and is only loaded where used.
import 'package:timezone/data/latest_all.dart' deferred as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/settings.dart';
import '../core/strings.dart';

enum Reminder {
  morning(1, TimeOfDay(hour: 6, minute: 0)),
  evening(2, TimeOfDay(hour: 17, minute: 0));

  const Reminder(this.id, this.defaultTime);
  final int id;
  final TimeOfDay defaultTime;

  String get label => this == morning ? t('أذكار الصباح', 'Morning azkar') : t('أذكار المساء', 'Evening azkar');
  String get title =>
      this == morning ? t('حان وقت أذكار الصباح', 'Time for the morning azkar') : t('حان وقت أذكار المساء', 'Time for the evening azkar');

  bool enabledIn(SharedPreferences p) => p.getBool('reminder.$name.on') ?? false;

  TimeOfDay timeIn(SharedPreferences p) {
    final m = p.getInt('reminder.$name.min');
    return m == null ? defaultTime : TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  Future<void> saveIn(SharedPreferences p, {bool? on, TimeOfDay? time}) async {
    if (on != null) await p.setBool('reminder.$name.on', on);
    if (time != null) await p.setInt('reminder.$name.min', time.hour * 60 + time.minute);
  }
}

/// Next occurrence of [time] strictly after [now], in [now]'s location (DST-safe).
tz.TZDateTime nextInstance(tz.TZDateTime now, TimeOfDay time) {
  final today = tz.TZDateTime(now.location, now.year, now.month, now.day, time.hour, time.minute);
  return today.isAfter(now)
      ? today
      : tz.TZDateTime(now.location, now.year, now.month, now.day + 1, time.hour, time.minute);
}

abstract final class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<bool>? _init;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Safe to call repeatedly; never throws. Returns false where notifications are unavailable.
  static Future<bool> init() => _init ??= _doInit();

  static Future<bool> _doInit() async {
    if (!supported) return false;
    try {
      await tzdata.loadLibrary();
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      var locale = Settings.I.locale;
      Settings.I.addListener(() {
        if (Settings.I.locale == locale) return;
        locale = Settings.I.locale;
        unawaited(_applyAll());
      });
      // Also picks up a time-zone change since the last launch.
      await _applyAll();
      return true;
    } catch (e) {
      debugPrint('Reminders init failed: $e');
      return false;
    }
  }

  /// Turns a reminder on/off. Returns false if turning on failed (e.g. permission denied).
  static Future<bool> setEnabled(Reminder r, bool on) async {
    if (!await init()) return false;
    if (on && !await _requestPermission()) return false;
    await r.saveIn(Settings.I.prefs, on: on);
    await _apply(r);
    return true;
  }

  static Future<void> setTime(Reminder r, TimeOfDay time) async {
    await r.saveIn(Settings.I.prefs, time: time);
    if (await init()) await _apply(r);
  }

  static Future<bool> _requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          true;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  static Future<void> _applyAll() async {
    for (final r in Reminder.values) {
      await _apply(r);
    }
  }

  static Future<void> _apply(Reminder r) async {
    final prefs = Settings.I.prefs;
    await _plugin.cancel(id: r.id);
    if (!r.enabledIn(prefs)) return;
    await _plugin.zonedSchedule(
      id: r.id,
      title: r.title,
      body: t('افتح التطبيق لقراءة الأذكار', 'Open the app to read your azkar'),
      scheduledDate: nextInstance(tz.TZDateTime.now(tz.local), r.timeIn(prefs)),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'azkar_reminders',
          t('تذكير الأذكار', 'Azkar reminders'),
          channelDescription: t('تذكير يومي بأذكار الصباح والمساء', 'Daily morning and evening azkar reminders'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Inexact: no SCHEDULE_EXACT_ALARM permission needed; may fire a few minutes late.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
