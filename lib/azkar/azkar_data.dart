import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/settings.dart';

class Dhikr {
  Dhikr({
    required this.id,
    required this.ar,
    this.en,
    this.count = 1,
    this.book,
    this.number,
    this.noteAr,
    this.noteEn,
  })  : searchAr = normalizeAr(ar),
        searchEn = en?.toLowerCase() ?? '';

  final String id;
  final String ar;
  final String? en;
  final int count;
  final String? book;
  final int? number;
  final String? noteAr;
  final String? noteEn;

  // Precomputed once at load so search does no per-keystroke work on items.
  final String searchAr;
  final String searchEn;

  static Dhikr? fromJson(Object? j) {
    if (j is! Map) return null;
    final ar = _str(j['ar']);
    if (ar == null) return null;
    final count = j['count'];
    final number = j['number'];
    return Dhikr(
      id: _str(j['id']) ?? ar,
      ar: ar,
      en: _str(j['en']),
      count: count is num && count >= 1 ? count.toInt() : 1,
      book: _str(j['book']),
      number: number is num ? number.toInt() : null,
      noteAr: _str(j['note_ar']),
      noteEn: _str(j['note_en']),
    );
  }
}

class AzkarCategory {
  const AzkarCategory({required this.id, required this.ar, required this.en, required this.items});

  final String id;
  final String ar;
  final String en;
  final List<Dhikr> items;

  static AzkarCategory? fromJson(Object? j) {
    if (j is! Map) return null;
    final raw = j['items'];
    final items = [
      if (raw is List)
        for (final i in raw) ?Dhikr.fromJson(i),
    ];
    if (items.isEmpty) return null;
    final ar = _str(j['ar']) ?? _str(j['en']) ?? '';
    return AzkarCategory(id: _str(j['id']) ?? ar, ar: ar, en: _str(j['en']) ?? ar, items: items);
  }
}

String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

List<AzkarCategory> parseAzkar(String src) {
  final root = jsonDecode(src);
  final cats = root is Map ? root['categories'] : null;
  if (cats is! List) return const [];
  return [for (final c in cats) ?AzkarCategory.fromJson(c)];
}

Future<List<AzkarCategory>>? _cache;

Future<List<AzkarCategory>> loadAzkar() => _cache ??= rootBundle
        .loadString('assets/azkar.json')
        .then((s) => compute(parseAzkar, s))
        .catchError((Object e) {
      _cache = null; // allow a retry on next build
      throw e;
    });

final _tashkeel = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');
final _alef = RegExp('[آأإٱ]');
final _ya = RegExp('[ئى]');

/// Strips diacritics/tatweel and folds alef, hamza, ya and ta-marbuta forms.
String normalizeAr(String s) => s
    .replaceAll(_tashkeel, '')
    .replaceAll(_alef, 'ا')
    .replaceAll('ؤ', 'و')
    .replaceAll(_ya, 'ي')
    .replaceAll('ة', 'ه');

List<Dhikr> searchAzkar(Iterable<Dhikr> all, String query) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final ar = normalizeAr(q);
  final en = q.toLowerCase();
  return [
    for (final d in all)
      if (d.searchAr.contains(ar) || d.searchEn.contains(en)) d,
  ];
}

// Per-session repeat progress, shared by every list showing the same item.
final _progress = <String, ValueNotifier<int>>{};

ValueNotifier<int> progressOf(Dhikr d) => _progress.putIfAbsent(d.id, () => ValueNotifier(0));

/// Increments toward [Dhikr.count]; returns true when this tap completed it.
bool countTap(Dhikr d) {
  final p = progressOf(d);
  if (p.value >= d.count) return false;
  p.value++;
  return p.value == d.count;
}

void resetProgress(Iterable<Dhikr> items) {
  for (final d in items) {
    _progress[d.id]?.value = 0;
  }
}

class Favorites {
  static const _key = 'azkar_favs';
  static ValueNotifier<Set<String>>? _n;

  static ValueNotifier<Set<String>> get notifier =>
      _n ??= ValueNotifier({...?Settings.I.prefs.getStringList(_key)});

  static void toggle(String id) {
    final s = {...notifier.value};
    if (!s.remove(id)) s.add(id);
    notifier.value = s;
    Settings.I.prefs.setStringList(_key, s.toList());
  }
}
