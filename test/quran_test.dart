import 'dart:io';

import 'package:azkar/core/settings.dart';
import 'package:azkar/quran/quran_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  final surahs = parseSurahs(read('assets/quran/surahs.json'));

  test('surahs.json has 114 surahs and 6236 ayahs', () {
    expect(surahs.length, 114);
    expect(surahs.fold<int>(0, (t, s) => t + s.ayahs), 6236);
    expect([for (final s in surahs) s.n], List.generate(114, (i) => i + 1));
  });

  test('surah files match surahs.json', () {
    for (final n in [1, 2, 9, 112, 114]) {
      final ayahs = parseSurah(read('assets/quran/${'$n'.padLeft(3, '0')}.json'));
      expect(ayahs.length, surahs[n - 1].ayahs, reason: 'surah $n');
      expect([for (final a in ayahs) a.n], List.generate(ayahs.length, (i) => i + 1));
      expect(ayahs.last.text, endsWith('۝${arabicDigits(ayahs.length)}'));
    }
  });

  test('normalization + search finds the ayah a query came from', () {
    final lines = parseSearch(read('assets/quran/search.txt'));
    expect(lines.length, 6236);
    for (final n in [0, 1000, 4321, 6235]) {
      final line = lines[n];
      final words = line.text.split(' ');
      final plain = words.take(3).join(' ');
      expect(normalizeArabic(plain), plain, reason: 'file text is already normalized');
      // Decorate the query with a fatha after every letter and a hamza-alef, then expect it to normalize back.
      final decorated = '  ${plain.split('').join('َ').replaceFirst('ا', 'أ')}  ';
      expect(normalizeArabic(decorated), plain);
      final r = searchQuran(lines, decorated, cap: 10000);
      expect(r.hits.any((h) => h.$1.s == line.s && h.$1.a == line.a), isTrue, reason: '${line.s}:${line.a}');
      expect(r.total, r.hits.length);
    }
    expect(searchQuran(lines, '  ').total, 0);
    final capped = searchQuran(lines, lines[0].text.split(' ').last, cap: 5);
    expect(capped.hits.length, lessThanOrEqualTo(5));
  });

  List<Ayah> surah(int n) => parseSurah(read('assets/quran/${'$n'.padLeft(3, '0')}.json'));

  test('continuous chunking of Al-Baqarah covers each ayah once and respects the budget', () {
    final ayahs = surah(2);
    final starts = chunkAyahs(ayahs);
    expect(starts.first, 0);
    final seen = <int>[];
    for (var c = 0; c < starts.length; c++) {
      final end = c + 1 < starts.length ? starts[c + 1] : ayahs.length;
      expect(end, greaterThan(starts[c]), reason: 'chunk $c is empty');
      final chunk = ayahs.sublist(starts[c], end);
      seen.addAll(chunk.map((a) => a.n));
      if (chunk.length > 1) {
        expect(chunk.fold<int>(0, (t, a) => t + a.text.length), lessThanOrEqualTo(chunkBudget), reason: 'chunk $c');
      }
    }
    expect(seen, List.generate(286, (i) => i + 1));
    // 2:282 (longest ayah) is over the budget, so it stands alone.
    expect(ayahs[281].text.length, greaterThan(chunkBudget));
    final c282 = chunkOf(starts, 282);
    expect(starts[c282], 281);
    expect(c282 + 1 < starts.length ? starts[c282 + 1] : ayahs.length, 282);

    for (final a in [1, 2, 100, 255, 281, 282, 283, 286]) {
      final c = chunkOf(starts, a);
      final end = c + 1 < starts.length ? starts[c + 1] : ayahs.length;
      expect(a - 1, inInclusiveRange(starts[c], end - 1), reason: 'ayah $a');
      // First ayah of a chunk maps back to that chunk (last-read / layout-switch round trip).
      expect(chunkOf(starts, ayahs[starts[c]].n), c);
    }
    expect(chunkOf(starts, 1), 0);
    expect(chunkOf(starts, 286), starts.length - 1);
    expect(identical(chunksOf(ayahs), chunksOf(ayahs)), isTrue, reason: 'cached per parsed surah');
  });

  test('a short surah is a single chunk', () {
    expect(chunkAyahs(surah(112)), [0]);
  });

  group('prefs', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await Settings.I.load();
    });

    test('bookmark toggle persists', () {
      QuranStore().toggleBookmark(2, 255);
      expect(QuranStore().isBookmarked(2, 255), isTrue);
      expect(Settings.I.prefs.getStringList('quran_bookmarks'), ['2:255']);
      QuranStore().toggleBookmark(2, 255);
      expect(QuranStore().isBookmarked(2, 255), isFalse);
    });

    test('last read persists', () {
      expect(QuranStore().lastRead.value, isNull);
      QuranStore().setLastRead(18, 10);
      expect(QuranStore().lastRead.value, (s: 18, a: 10));
    });

    test('layout persists and defaults to ayah by ayah', () {
      expect(QuranStore().layout.value, QuranLayout.ayah);
      QuranStore().setLayout(QuranLayout.continuous);
      expect(Settings.I.prefs.getString('quran_layout'), 'continuous');
      expect(QuranStore().layout.value, QuranLayout.continuous);
      Settings.I.prefs.setString('quran_layout', 'bogus');
      expect(QuranStore().layout.value, QuranLayout.ayah);
    });
  });
}
