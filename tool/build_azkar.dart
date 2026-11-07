// Builds assets/azkar.json from tool/azkar_selection.json + cached hadith
// datasets (fawazahmed0/hadith-api, see tool/README.md).
//
// Every Arabic/English string shipped is CUT from the dataset hadith text by
// markers; the script asserts it is a verbatim substring and exits non-zero
// on any failure.
//
// Usage (from project root):
//   dart run tool/build_azkar.dart                 # download (if needed) + build
//   dart run tool/build_azkar.dart search muslim "سبحان الله وبحمده"
//   dart run tool/build_azkar.dart show bukhari 6306
import 'dart:convert';
import 'dart:io';

const cacheDir = 'tool/hadith_cache';
const baseUrl = 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions';
const books = {'bukhari', 'muslim'};

/// Dataset hadithnumber -> "arabicnumber" (Abd al-Baqi numbering, which is
/// what sunnah.com shows; "2692.01" = 2nd chain under 2692).
final refs = <String, Map<int, String>>{};

Future<Map<int, String>> load(String edition) async {
  final f = File('$cacheDir/$edition.json');
  if (!f.existsSync()) {
    stderr.writeln('downloading $edition ...');
    f.parent.createSync(recursive: true);
    final req = await HttpClient().getUrl(Uri.parse('$baseUrl/$edition.json'));
    final res = await req.close();
    if (res.statusCode != 200) fail('download $edition: HTTP ${res.statusCode}');
    await res.pipe(f.openWrite());
  }
  final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final out = <int, String>{};
  for (final h in data['hadiths'] as List) {
    final n = (h['hadithnumber'] as num);
    // Some datasets use fractional numbers for sub-narrations; keep integers.
    if (n == n.toInt()) {
      out.putIfAbsent(n.toInt(), () => h['text'] as String);
      (refs[edition] ??= {})
          .putIfAbsent(n.toInt(), () => '${h['arabicnumber'] ?? ''}');
    }
  }
  return out;
}

Never fail(String msg) {
  stderr.writeln('ERROR: $msg');
  exit(1);
}

// Diacritics and tatweel: ignored when matching, and kept when they trail the
// last matched letter of a cut.
bool isMark(int c) =>
    (c >= 0x064B && c <= 0x065F) ||
    c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06ED) ||
    c == 0x0640;

// Also ignored when matching: bidi marks and punctuation.
bool isIgnorable(int c) =>
    isMark(c) || c == 0x200E || c == 0x200F || '،,.؛"'.codeUnits.contains(c);

String foldChar(int c) {
  switch (c) {
    case 0x0623: case 0x0625: case 0x0622: case 0x0671: return 'ا';
    case 0x0649: return 'ي';
    case 0x0629: return 'ه';
    case 0x0624: return 'و';
    case 0x0626: return 'ي';
  }
  return String.fromCharCode(c);
}

/// Normalised text plus, for each normalised char, its index in the original.
(String, List<int>) normalize(String s) {
  final b = StringBuffer();
  final idx = <int>[];
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (isIgnorable(c)) continue;
    // Collapse whitespace runs (punctuation removal leaves double spaces).
    if (c == 0x20 && idx.isNotEmpty && s.codeUnitAt(idx.last) == 0x20) continue;
    b.write(foldChar(c));
    idx.add(i);
  }
  return (b.toString(), idx);
}

String norm(String s) => normalize(s).$1;

/// Cut the original text from the start of [start] to the end of [end]
/// (both matched diacritics-insensitively). Trailing diacritics of the last
/// matched letter are kept.
/// [after] (optional) anchors the search: start is the first match after it.
String cutAr(String text, String start, String end, String? after, String ctx) {
  final (n, idx) = normalize(text);
  final ns = norm(start), ne = norm(end);
  var from = 0;
  if (after != null) {
    from = n.indexOf(norm(after));
    if (from < 0) fail('$ctx: ar after-anchor not found: $after');
  }
  final a = n.indexOf(ns, from);
  if (a < 0) fail('$ctx: ar start marker not found: $start');
  final e = n.indexOf(ne, a);
  if (e < 0) fail('$ctx: ar end marker not found after start: $end');
  var stop = idx[e + ne.length - 1] + 1;
  while (stop < text.length && isMark(text.codeUnitAt(stop))) {
    stop++;
  }
  return text.substring(idx[a], stop);
}

String cutEn(String text, String start, String end, String? after, String ctx) {
  var from = 0;
  if (after != null) {
    from = text.indexOf(after);
    if (from < 0) fail('$ctx: en after-anchor not found: $after');
  }
  final a = text.indexOf(start, from);
  if (a < 0) fail('$ctx: en start marker not found: $start');
  final e = text.indexOf(end, a);
  if (e < 0) fail('$ctx: en end marker not found after start: $end');
  return text.substring(a, e + end.length);
}

Future<void> main(List<String> args) async {
  final data = <String, Map<int, String>>{};
  for (final b in books) {
    data['ara-$b'] = await load('ara-$b');
    data['eng-$b'] = await load('eng-$b');
  }

  if (args.isNotEmpty && args[0] == 'search') {
    final lang = RegExp(r'[a-zA-Z]').hasMatch(args[2]) ? 'eng' : 'ara';
    final q = lang == 'ara' ? norm(args[2]) : args[2].toLowerCase();
    data['$lang-${args[1]}']!.forEach((k, v) {
      final t = lang == 'ara' ? norm(v) : v.toLowerCase();
      final i = t.indexOf(q);
      if (i >= 0) {
        final s = (i - 60).clamp(0, t.length), e = (i + 160).clamp(0, t.length);
        print('$k [ref ${refs['ara-${args[1]}']![k]}]: ${t.substring(s, e)}');
      }
    });
    return;
  }
  if (args.isNotEmpty && args[0] == 'show') {
    final n = int.parse(args[2]);
    print(data['ara-${args[1]}']![n]);
    print('---');
    print(data['eng-${args[1]}']![n]);
    return;
  }

  final sel = jsonDecode(File('tool/azkar_selection.json').readAsStringSync())
      as Map<String, dynamic>;
  final ids = <String>{};
  final cats = [];
  for (final c in sel['categories'] as List) {
    final items = [];
    for (final it in c['items'] as List) {
      final id = it['id'] as String, book = it['book'] as String;
      final number = it['number'] as int, count = (it['count'] ?? 1) as int;
      if (!ids.add(id)) fail('duplicate id $id');
      if (!books.contains(book)) fail('$id: bad book $book');
      if (count < 1) fail('$id: count < 1');
      final ar = data['ara-$book']![number], en = data['eng-$book']![number];
      if (ar == null || en == null) fail('$id: $book $number missing in dataset');
      // A count > 1 must be backed by a phrase in the hadith text itself.
      if (count > 1) {
        final proof = it['count_proof_ar'] as String?;
        if (proof == null || !norm(ar).contains(norm(proof))) {
          fail('$id: count $count without count_proof_ar found in hadith');
        }
      }
      // number = sunnah.com-style (Abd al-Baqi) number; dataset_number = the
      // fawazahmed0 hadithnumber the text was cut from (differs for Muslim).
      final ref = refs['ara-$book']![number]!;
      final refNum = int.tryParse(ref.split('.').first);
      if (refNum == null) fail('$id: $book $number has no arabicnumber');
      final out = <String, dynamic>{
        'id': id,
        'ar': cutAr(ar, it['ar_start'], it['ar_end'], it['ar_after'], id),
        'en': it['en_full'] == true
            ? en.trim()
            : cutEn(en, it['en_start'], it['en_end'], it['en_after'], id),
        'count': count,
        'book': book,
        'number': refNum,
        // sunnah.com suffix: dataset "2723.03" == sunnah.com "2723c".
        'ref': ref.contains('.')
            ? '$refNum${String.fromCharCode(96 + int.parse(ref.split('.')[1]))}'
            : '$refNum',
        'dataset_number': number,
      };
      if (it['note_ar_start'] != null) {
        out['note_ar'] = cutAr(ar, it['note_ar_start'], it['note_ar_end'], null, '$id note');
      }
      if (it['note_en_start'] != null) {
        out['note_en'] = cutEn(en, it['note_en_start'], it['note_en_end'], null, '$id note');
      }
      // Belt and braces: re-assert verbatim substrings of the cited hadith.
      for (final k in ['ar', 'note_ar']) {
        if (out[k] != null && (out[k].isEmpty || !ar.contains(out[k]))) fail('$id: $k not substring');
      }
      for (final k in ['en', 'note_en']) {
        if (out[k] != null && (out[k].isEmpty || !en.contains(out[k]))) fail('$id: $k not substring');
      }
      items.add(out);
      if (args.contains('--list')) {
        print('  $id $book ${out['ref']} (ds $number) x$count | ${out['ar']}\n'
            '      EN: ${out['en']}\n      NOTE: ${out['note_ar'] ?? '-'} | ${out['note_en'] ?? '-'}');
      }
    }
    if (items.isEmpty) fail('category ${c['id']} is empty');
    cats.add({'id': c['id'], 'ar': c['ar'], 'en': c['en'], 'items': items});
    print('${(c['id'] as String).padRight(20)} ${items.length} items');
  }
  File('assets/azkar.json').writeAsStringSync(jsonEncode({'categories': cats}));
  print('total ${ids.length} items -> assets/azkar.json');
}
