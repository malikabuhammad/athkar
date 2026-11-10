import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../core/settings.dart';
import '../core/settings_page.dart';
import '../core/strings.dart';
import 'prayer_calc.dart';

enum _LocState { ask, denied, deniedForever, serviceOff, error }

class PrayerTab extends StatefulWidget {
  const PrayerTab({super.key});

  @override
  State<PrayerTab> createState() => _PrayerTabState();
}

class _PrayerTabState extends State<PrayerTab> {
  final _prefs = Settings.I.prefs;
  double? _lat, _lng;
  bool _busy = false;
  _LocState _locState = _LocState.ask;

  late CalculationMethod _method = CalculationMethod.values
          .asNameMap()[_prefs.getString('prayer.method')] ??
      CalculationMethod.muslim_world_league;
  late Madhab _madhab = _prefs.getString('prayer.madhab') == Madhab.hanafi.name
      ? Madhab.hanafi
      : Madhab.shafi;

  late DateTime _day;
  List<DateTime> _today = const [];
  DateTime? _tomorrowFajr;

  /// Ticks once per minute (aligned to the minute); only the times list listens.
  final _now = ValueNotifier(DateTime.now());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lat = _prefs.getDouble('prayer.lat');
    _lng = _prefs.getDouble('prayer.lng');
    _recompute();
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _now.dispose();
    super.dispose();
  }

  void _arm() {
    final n = DateTime.now();
    _timer = Timer(Duration(seconds: 60 - n.second, milliseconds: -n.millisecond), _tick);
  }

  void _tick() {
    final n = DateTime.now();
    if (n.day != _day.day || n.month != _day.month || n.year != _day.year) {
      setState(_recompute);
    }
    _now.value = n;
    _arm();
  }

  void _recompute() {
    final n = DateTime.now();
    _day = DateTime(n.year, n.month, n.day);
    if (_lat == null) return;
    _today = dayTimes(_lat!, _lng!, _day, _method, _madhab);
    _tomorrowFajr = dayTimes(_lat!, _lng!, DateTime(n.year, n.month, n.day + 1), _method, _madhab)[0];
    _now.value = n;
  }

  Future<void> _locate() async {
    setState(() => _busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _fail(_LocState.serviceOff);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return _fail(_LocState.denied);
      if (perm == LocationPermission.deniedForever) return _fail(_LocState.deniedForever);
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } on TimeoutException {
        final last = kIsWeb ? null : await Geolocator.getLastKnownPosition();
        if (last == null) rethrow;
        pos = last;
      }
      await _prefs.setDouble('prayer.lat', pos.latitude);
      await _prefs.setDouble('prayer.lng', pos.longitude);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lat = pos.latitude;
        _lng = pos.longitude;
        _recompute();
      });
    } catch (_) {
      _fail(_LocState.error);
    }
  }

  void _fail(_LocState s) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _locState = s;
    });
    // With a cached location we keep showing times and just report the failure.
    if (_lat != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(s).$2)));
    }
  }

  (String, String) _message(_LocState s) => switch (s) {
        _LocState.ask => (
            t('نحتاج إلى موقعك', 'Your location is needed'),
            t('تُحسب مواقيت الصلاة على جهازك من موقعك التقريبي، ولا يُرسل موقعك إلى أي جهة.',
                'Prayer times are calculated on your device from your approximate location. Your location is never sent anywhere.'),
          ),
        _LocState.denied => (
            t('لم يُسمح بالوصول إلى الموقع', 'Location permission denied'),
            t('اسمح بالوصول إلى الموقع لحساب مواقيت الصلاة.', 'Allow location access to calculate prayer times.'),
          ),
        _LocState.deniedForever => (
            t('الوصول إلى الموقع مرفوض', 'Location access is blocked'),
            t('فعّل إذن الموقع للتطبيق من الإعدادات ثم أعد المحاولة.',
                'Enable the location permission for this app in Settings, then try again.'),
          ),
        _LocState.serviceOff => (
            t('خدمة الموقع متوقفة', 'Location is turned off'),
            t('شغّل خدمة الموقع في جهازك ثم أعد المحاولة.', 'Turn on location services on your device, then try again.'),
          ),
        _LocState.error => (
            t('تعذّر تحديد الموقع', 'Could not get your location'),
            t('تحقق من خدمة الموقع وأعد المحاولة.', 'Check your location services and try again.'),
          ),
      };

  void _setMethod(CalculationMethod m) {
    _prefs.setString('prayer.method', m.name);
    setState(() {
      _method = m;
      _recompute();
    });
  }

  void _setMadhab(Madhab m) {
    _prefs.setString('prayer.madhab', m.name);
    setState(() {
      _madhab = m;
      _recompute();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(t('مواقيت الصلاة', 'Prayer Times')),
          actions: [
            if (_lat != null)
              _busy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.my_location),
                      tooltip: t('تحديث الموقع', 'Refresh location'),
                      onPressed: _locate,
                    ),
            const SettingsButton(),
          ],
        ),
        body: _lat != null
            ? _times(context)
            : _busy
                ? const Center(child: CircularProgressIndicator())
                : _locationCard(context),
      );

  Widget _locationCard(BuildContext context) {
    final (title, body) = _message(_locState);
    final canOpenSettings = !kIsWeb &&
        (_locState == _LocState.deniedForever || _locState == _LocState.serviceOff);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_locState == _LocState.ask ? Icons.location_on_outlined : Icons.location_off_outlined,
                    size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: Text(_locState == _LocState.ask
                      ? t('استخدام موقعي', 'Use my location')
                      : t('إعادة المحاولة', 'Try again')),
                  onPressed: _locate,
                ),
                if (canOpenSettings)
                  TextButton(
                    onPressed: _locState == _LocState.serviceOff
                        ? Geolocator.openLocationSettings
                        : Geolocator.openAppSettings,
                    child: Text(t('فتح الإعدادات', 'Open settings')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _times(BuildContext context) {
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    String fmt(DateTime d) => loc.formatTimeOfDay(TimeOfDay.fromDateTime(d), alwaysUse24HourFormat: use24);
    final names = prayerNames();
    final labels = methodLabels();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(loc.formatFullDate(_day), style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ValueListenableBuilder<DateTime>(
          valueListenable: _now,
          builder: (context, now, _) {
            final next = nextIndex(_today, now);
            final nextAt = next < 6 ? _today[next] : _tomorrowFajr!;
            final nextName = next < 6 ? names[next] : '${names[0]} ${t('(غداً)', '(tomorrow)')}';
            return Column(
              children: [
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(t('القادمة: $nextName', 'Next: $nextName')),
                    subtitle: Text(t('بعد ${formatRemaining(nextAt.difference(now))}',
                        'in ${formatRemaining(nextAt.difference(now))}')),
                    trailing: Text(fmt(nextAt), style: theme.textTheme.titleMedium),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < 6; i++)
                        ListTile(
                          selected: i == next,
                          selectedTileColor: theme.colorScheme.secondaryContainer,
                          title: Text(names[i]),
                          trailing: Text(fmt(_today[i]),
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: i == next ? FontWeight.bold : null,
                                  color: i == next ? theme.colorScheme.primary : null)),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(t('طريقة الحساب', 'Calculation method'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownMenu<CalculationMethod>(
          initialSelection: _method,
          expandedInsets: EdgeInsets.zero,
          onSelected: (m) {
            if (m != null) _setMethod(m);
          },
          dropdownMenuEntries: [
            for (final e in labels.entries) DropdownMenuEntry(value: e.key, label: e.value),
          ],
        ),
        const SizedBox(height: 16),
        Text(t('حساب العصر', 'Asr calculation'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<Madhab>(
          segments: [
            ButtonSegment(value: Madhab.shafi, label: Text(t('الجمهور (شافعي)', 'Standard (Shafi)'))),
            ButtonSegment(value: Madhab.hanafi, label: Text(t('حنفي', 'Hanafi'))),
          ],
          selected: {_madhab},
          onSelectionChanged: (v) => _setMadhab(v.first),
        ),
        const SizedBox(height: 16),
        Text(
          '${_lat!.toStringAsFixed(3)}, ${_lng!.toStringAsFixed(3)}',
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
