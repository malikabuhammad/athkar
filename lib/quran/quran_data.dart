import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/settings.dart';

class SurahInfo {
  const SurahInfo(this.n, this.ar, this.en, this.meaning, this.ayahs, this.meccan, this.key);
  final int n, ayahs;
  final String ar, en, meaning;
  final bool meccan;

  /// Lower-cased, normalized "number arabic english meaning" for the index filter.
  final String key;
}

class Ayah {
  const Ayah(this.n, this.ar, this.tafsir, this.en, this.text);
  final int n;
  final String ar, tafsir, en;

  /// [ar] + end-of-ayah mark with Arabic-Indic number, built off the UI thread.
  final String text;
}

typedef SearchLine = ({int s, int a, String text});

class SearchResult {
  const SearchResult(this.total, this.hits, this.length);
  final int total;

  /// Capped list of (line, match start); [length] is the normalized query length.
  final List<(SearchLine, int)> hits;
  final int length;
}

String arabicDigits(int n) => String.fromCharCodes('$n'.codeUnits.map((c) => c + 0x0630));
String localNum(int n) => Settings.I.isAr ? arabicDigits(n) : '$n';

// Same transform tool/build_quran.dart applies to search.txt: strip harakat, Quranic marks,
// dagger alef and tatweel; أ إ آ ٱ → ا; collapse spaces. ى and ة are left as-is there too.
final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');
final _alef = RegExp('[أإآٱ]');
final _space = RegExp(r'\s+');
String normalizeArabic(String s) =>
    s.replaceAll(_marks, '').replaceAll(_alef, 'ا').replaceAll(_space, ' ').trim();

List<SurahInfo> parseSurahs(String json) => [
      for (final m in (jsonDecode(json) as List).cast<Map<String, dynamic>>())
        SurahInfo(
          m['n'] as int,
          m['ar'] as String,
          m['en'] as String,
          m['meaning'] as String,
          m['ayahs'] as int,
          m['type'] == 'meccan',
          '${m['n']} ${normalizeArabic(m['ar'] as String)} ${m['en']} ${m['meaning']}'.toLowerCase(),
        ),
    ];

List<Ayah> parseSurah(String json) => [
      for (final m in (jsonDecode(json) as List).cast<Map<String, dynamic>>())
        Ayah(
          m['n'] as int,
          m['ar'] as String,
          m['tafsir'] as String,
          m['en'] as String,
          '${m['ar']} ۝${arabicDigits(m['n'] as int)}',
        ),
    ];

/// ~1–1.5 screens of Quran text at the default font size (≈45–55 chars per line incl. harakat × ~13 lines).
const chunkBudget = 800;

/// Start index (into [ayahs]) of each chunk for the continuous layout: consecutive ayahs whose
/// [Ayah.text] lengths sum to at most [budget]; an ayah longer than [budget] is a chunk of its own.
List<int> chunkAyahs(List<Ayah> ayahs, {int budget = chunkBudget}) {
  final starts = <int>[];
  var used = 0;
  for (var i = 0; i < ayahs.length; i++) {
    final len = ayahs[i].text.length;
    if (starts.isEmpty || used + len > budget) {
      starts.add(i);
      used = 0;
    }
    used += len;
  }
  return starts;
}

/// Chunk index holding ayah number [ayah] (1-based) for [starts] from [chunkAyahs].
int chunkOf(List<int> starts, int ayah) {
  var lo = 0, hi = starts.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (starts[mid] <= ayah - 1) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}

// Lives as long as the parsed surah list (held by Quran's LRU), so chunking runs once per surah.
final _chunks = Expando<List<int>>();
List<int> chunksOf(List<Ayah> ayahs) => _chunks[ayahs] ??= chunkAyahs(ayahs);

enum QuranLayout { ayah, continuous, tafsir }

List<SearchLine> parseSearch(String txt) {
  final out = <SearchLine>[];
  for (final line in const LineSplitter().convert(txt)) {
    final i = line.indexOf('|'), j = line.indexOf('|', i + 1);
    if (j < 0) continue;
    out.add((s: int.parse(line.substring(0, i)), a: int.parse(line.substring(i + 1, j)), text: line.substring(j + 1)));
  }
  return out;
}

// shortcut: linear scan on the UI thread (~6k short strings, a few ms, debounced); move to an isolate if it ever janks.
SearchResult searchQuran(List<SearchLine> lines, String query, {int cap = 200}) {
  final q = normalizeArabic(query);
  if (q.isEmpty) return const SearchResult(0, [], 0);
  var total = 0;
  final hits = <(SearchLine, int)>[];
  for (final l in lines) {
    final at = l.text.indexOf(q);
    if (at < 0) continue;
    total++;
    if (hits.length < cap) hits.add((l, at));
  }
  return SearchResult(total, hits, q.length);
}

String _utf8(ByteData d) => utf8.decode(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
List<SurahInfo> _decodeSurahs(ByteData d) => parseSurahs(_utf8(d));
List<Ayah> _decodeSurah(ByteData d) => parseSurah(_utf8(d));
List<SearchLine> _decodeSearch(ByteData d) => parseSearch(_utf8(d));

/// Asset loading: bytes via rootBundle.load (not cached by the bundle), decoded in an isolate.
class Quran {
  static Future<List<SurahInfo>>? _surahs;
  static Future<List<SurahInfo>> surahs() => _surahs ??= _load('assets/quran/surahs.json', _decodeSurahs);

  static Future<List<SearchLine>>? _search;
  static Future<List<SearchLine>> searchLines() => _search ??= _load('assets/quran/search.txt', _decodeSearch);

  // Small LRU (Map keeps insertion order).
  static final _cache = <int, Future<List<Ayah>>>{};
  static Future<List<Ayah>> surah(int n) {
    final f = _cache.remove(n) ?? _load('assets/quran/${'$n'.padLeft(3, '0')}.json', _decodeSurah);
    _cache[n] = f;
    if (_cache.length > 6) _cache.remove(_cache.keys.first);
    return f;
  }

  static Future<T> _load<T>(String path, ComputeCallback<ByteData, T> decode) async =>
      compute(decode, await rootBundle.load(path));
}

/// Bookmarks ("surah:ayah" list under 'quran_bookmarks') and last-read position.
class QuranStore {
  QuranStore()
      : bookmarks = ValueNotifier(Settings.I.prefs.getStringList(_bkKey)?.toSet() ?? <String>{}),
        lastRead = ValueNotifier(_readLast()),
        layout = ValueNotifier(QuranLayout.values.asNameMap()[Settings.I.prefs.getString(_lyKey)] ?? QuranLayout.ayah);
  static final QuranStore I = QuranStore();

  static const _bkKey = 'quran_bookmarks', _lsKey = 'quran_last_surah', _laKey = 'quran_last_ayah';
  static const _lyKey = 'quran_layout';

  final ValueNotifier<Set<String>> bookmarks;
  final ValueNotifier<({int s, int a})?> lastRead;
  final ValueNotifier<QuranLayout> layout;

  void setLayout(QuranLayout v) {
    layout.value = v;
    Settings.I.prefs.setString(_lyKey, v.name);
  }

  static ({int s, int a})? _readLast() {
    final p = Settings.I.prefs, s = p.getInt(_lsKey), a = p.getInt(_laKey);
    return s == null || a == null ? null : (s: s, a: a);
  }

  bool isBookmarked(int s, int a) => bookmarks.value.contains('$s:$a');

  void toggleBookmark(int s, int a) {
    final next = {...bookmarks.value};
    if (!next.remove('$s:$a')) next.add('$s:$a');
    bookmarks.value = next;
    Settings.I.prefs.setStringList(_bkKey, next.toList());
  }

  void setLastRead(int s, int a) {
    if (lastRead.value == (s: s, a: a)) return;
    Settings.I.prefs
      ..setInt(_lsKey, s)
      ..setInt(_laKey, a);
    lastRead.value = (s: s, a: a);
  }
}
