import 'package:adhan/adhan.dart';

import '../core/strings.dart';

/// The package's methods we offer (CalculationMethod.other has 0° angles, so it's left out).
Map<CalculationMethod, String> methodLabels() => {
      CalculationMethod.muslim_world_league: t('رابطة العالم الإسلامي', 'Muslim World League'),
      CalculationMethod.egyptian: t('الهيئة المصرية العامة للمساحة', 'Egyptian General Authority'),
      CalculationMethod.karachi: t('جامعة العلوم الإسلامية بكراتشي', 'Univ. of Islamic Sciences, Karachi'),
      CalculationMethod.umm_al_qura: t('أم القرى، مكة المكرمة', 'Umm al-Qura, Makkah'),
      CalculationMethod.dubai: t('دبي', 'Dubai'),
      CalculationMethod.qatar: t('قطر', 'Qatar'),
      CalculationMethod.kuwait: t('الكويت', 'Kuwait'),
      CalculationMethod.moon_sighting_committee: t('لجنة رؤية الهلال', 'Moonsighting Committee'),
      CalculationMethod.singapore: t('سنغافورة', 'Singapore'),
      CalculationMethod.turkey: t('تركيا', 'Turkey'),
      CalculationMethod.tehran: t('طهران', 'Tehran'),
      CalculationMethod.north_america: t('أمريكا الشمالية (ISNA)', 'North America (ISNA)'),
    };

List<String> prayerNames() => [
      t('الفجر', 'Fajr'),
      t('الشروق', 'Sunrise'),
      t('الظهر', 'Dhuhr'),
      t('العصر', 'Asr'),
      t('المغرب', 'Maghrib'),
      t('العشاء', 'Isha'),
    ];

/// Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha for the local calendar date of [day].
List<DateTime> dayTimes(double lat, double lng, DateTime day, CalculationMethod method, Madhab madhab) {
  final params = method.getParameters()..madhab = madhab;
  final p = PrayerTimes(Coordinates(lat, lng), DateComponents.from(day), params);
  return [p.fajr, p.sunrise, p.dhuhr, p.asr, p.maghrib, p.isha];
}

/// Index into [today] of the next time after [now]; 6 means tomorrow's Fajr.
int nextIndex(List<DateTime> today, DateTime now) {
  final i = today.indexWhere((d) => d.isAfter(now));
  return i < 0 ? 6 : i;
}

/// Rounded up to the minute so it never reads "0m" before the time arrives.
String formatRemaining(Duration d) {
  final total = (d.inSeconds + 59) ~/ 60;
  final h = total ~/ 60, m = total % 60;
  if (h == 0) return t('$m د', '${m}m');
  return t('$h س $m د', '${h}h ${m}m');
}
