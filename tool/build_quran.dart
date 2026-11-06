// Builds assets/quran/ from api.alquran.cloud editions (cached in tool/quran_cache/).
// Run from project root: dart run tool/build_quran.dart
// Quran/tafsir/translation text is copied from the source; the only transforms are:
// removing a leading BOM, removing the basmala prefix from ayah 1 (surahs 2-8, 10-114),
// and, for search.txt only, stripping diacritics and normalizing alef variants.
import 'dart:convert';
import 'dart:io';

const cacheDir = 'tool/quran_cache';
const outDir = 'assets/quran';
const editions = ['quran-uthmani', 'ar.muyassar', 'en.sahih', 'quran-simple-clean'];

Future<List> load(String id) async {
  final f = File('$cacheDir/$id.json');
  if (!f.existsSync()) {
    stdout.writeln('Downloading $id ...');
    final req = await HttpClient().getUrl(Uri.parse('https://api.alquran.cloud/v1/quran/$id'));
    final res = await req.close();
    if (res.statusCode != 200) fail('HTTP ${res.statusCode} for $id');
    f.createSync(recursive: true);
    await res.pipe(f.openWrite());
  }
  final j = jsonDecode(f.readAsStringSync());
  if (j['code'] != 200) fail('$id: bad response code ${j['code']}');
  return j['data']['surahs'] as List;
}

Never fail(String msg) {
  stderr.writeln('CHECK FAILED: $msg');
  exit(1);
}

void check(bool ok, String msg) {
  if (!ok) fail(msg);
}

String clean(String s) => s.replaceAll('﻿', '');

// Arabic harakat, Quranic annotation marks, superscript (dagger) alef, tatweel.
final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');
final _alef = RegExp('[أإآٱ]');
String norm(String s) =>
    clean(s).replaceAll(_marks, '').replaceAll(_alef, 'ا').replaceAll(RegExp(r'\s+'), ' ').trim();

Future<void> main() async {
  final ed = {for (final id in editions) id: await load(id)};
  for (final id in editions) {
    check(ed[id]!.length == 114, '$id has ${ed[id]!.length} surahs');
  }
  final uth = ed['quran-uthmani']!, taf = ed['ar.muyassar']!, en = ed['en.sahih']!, simple = ed['quran-simple-clean']!;

  // Basmala as written in the source (surah 1 ayah 1), compared after normalization so
  // orthographic variants (e.g. an extra shadda) are still detected.
  final basmalaNorm = norm(uth[0]['ayahs'][0]['text']);
  final basmalaWords = basmalaNorm.split(' ').length;
  String stripBasmala(String text, int surah) {
    final t = clean(text);
    if (surah == 1 || surah == 9) return t;
    final words = t.split(' ');
    if (norm(words.take(basmalaWords).join(' ')) != basmalaNorm) {
      fail('surah $surah ayah 1 does not start with the basmala as expected');
    }
    return words.skip(basmalaWords).join(' ');
  }

  // Surah names in the source are all prefixed with the same word (سورة); drop it.
  final namePrefix = (uth[0]['name'] as String).split(' ').first;
  check(uth.every((s) => (s['name'] as String).startsWith('$namePrefix ')), 'surah name prefix differs');

  final outQuran = Directory(outDir)..createSync(recursive: true);
  final surahs = <Map<String, Object>>[];
  final search = <String>[];
  var total = 0;
  for (var i = 0; i < 114; i++) {
    final n = i + 1;
    final s = uth[i];
    final a = s['ayahs'] as List;
    for (final other in [taf, en, simple]) {
      check(other[i]['number'] == n && (other[i]['ayahs'] as List).length == a.length,
          'surah $n ayah count differs across editions');
    }
    final ayahs = <Map<String, Object>>[];
    for (var k = 0; k < a.length; k++) {
      check(a[k]['numberInSurah'] == k + 1, 'surah $n ayah ${k + 1} out of order');
      for (final other in [taf, en, simple]) {
        check(other[i]['ayahs'][k]['numberInSurah'] == k + 1, 'surah $n ayah ${k + 1} misaligned');
      }
      var ar = clean(a[k]['text']);
      var sc = clean(simple[i]['ayahs'][k]['text']);
      if (k == 0) {
        ar = stripBasmala(ar, n);
        sc = stripBasmala(sc, n);
      }
      final t = clean(taf[i]['ayahs'][k]['text']).trim();
      final e = clean(en[i]['ayahs'][k]['text']).trim();
      check(ar.trim().isNotEmpty && t.isNotEmpty && e.isNotEmpty, 'empty field in $n:${k + 1}');
      check(norm(sc).isNotEmpty, 'empty search text in $n:${k + 1}');
      ayahs.add({'n': k + 1, 'ar': ar, 'tafsir': t, 'en': e});
      search.add('$n|${k + 1}|${norm(sc)}');
    }
    total += a.length;
    surahs.add({
      'n': n,
      'ar': (s['name'] as String).substring(namePrefix.length + 1),
      'en': s['englishName'],
      'meaning': s['englishNameTranslation'],
      'ayahs': a.length,
      'type': (s['revelationType'] as String).toLowerCase(),
    });
    File('${outQuran.path}/${n.toString().padLeft(3, '0')}.json').writeAsStringSync(jsonEncode(ayahs));
  }
  File('$outDir/surahs.json').writeAsStringSync(jsonEncode(surahs));
  File('$outDir/search.txt').writeAsStringSync('${search.join('\n')}\n');

  // ---- Self-checks on the written files ----
  final rs = jsonDecode(File('$outDir/surahs.json').readAsStringSync()) as List;
  check(rs.length == 114, 'surahs.json has ${rs.length} entries');
  var sum = 0;
  var basmalaStarts = <int>[];
  for (final s in rs) {
    final n = s['n'] as int;
    final ay = jsonDecode(File('$outDir/${n.toString().padLeft(3, '0')}.json').readAsStringSync()) as List;
    check(ay.length == s['ayahs'], 'surah $n file has ${ay.length} ayahs, surahs.json says ${s['ayahs']}');
    check(['meccan', 'medinan'].contains(s['type']), 'surah $n type ${s['type']}');
    check((s['ar'] as String).isNotEmpty && (s['en'] as String).isNotEmpty, 'surah $n name empty');
    for (final x in ay) {
      for (final f in ['ar', 'tafsir', 'en']) {
        check((x[f] as String).trim().isNotEmpty, 'empty $f in $n:${x['n']}');
      }
    }
    if (norm(ay[0]['ar']).startsWith(basmalaNorm)) basmalaStarts.add(n);
    sum += ay.length;
  }
  check(sum == 6236, 'total ayahs $sum != 6236');
  check(total == 6236, 'total ayahs $total != 6236');
  check(basmalaStarts.length == 1 && basmalaStarts.first == 1, 'surahs starting with basmala: $basmalaStarts');
  final lines = File('$outDir/search.txt').readAsLinesSync();
  check(lines.length == 6236, 'search.txt has ${lines.length} lines');
  final searchBasmala = lines.where((l) => l.split('|')[1] == '1' && l.split('|')[2].startsWith(basmalaNorm));
  check(searchBasmala.length == 1 && searchBasmala.first.startsWith('1|1|'), 'search.txt basmala starts: ${searchBasmala.length}');
  // Surah 2 ayah 1 must be only the muqatta'at, consistent between Uthmani and simple-clean.
  final a21 = jsonDecode(File('$outDir/002.json').readAsStringSync())[0]['ar'] as String;
  check(!a21.contains(' ') && norm(a21) == lines.firstWhere((l) => l.startsWith('2|1|')).split('|')[2],
      '2:1 after basmala strip is "$a21"');

  final size = Directory(outDir).listSync().whereType<File>().fold<int>(0, (t, f) => t + f.lengthSync());
  stdout.writeln('OK: 114 surahs, $sum ayahs, 3 editions aligned, search.txt ${lines.length} lines');
  stdout.writeln('Basmala stripped from ayah 1 of ${114 - 2} surahs; 2:1 = $a21');
  stdout.writeln('assets/quran total: ${(size / 1024 / 1024).toStringAsFixed(2)} MB ($size bytes)');
}
