import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../core/settings.dart';
import '../core/settings_page.dart';
import '../core/strings.dart';
import 'quran_data.dart';

const quranFont = 'Quran';

void openReader(BuildContext context, List<SurahInfo> surahs, int surah, {int? ayah}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ReaderPage(surahs: surahs, surah: surah, ayah: ayah)));

/// Arabic name (Quran font) · English name — Ayah n (diacritized names need the Quran font).
class SurahRef extends StatelessWidget {
  const SurahRef({super.key, required this.info, required this.ayah, this.style});
  final SurahInfo info;
  final int ayah;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: info.ar, style: const TextStyle(fontFamily: quranFont)),
          TextSpan(text: ' · ${info.en} — ${t('آية', 'Ayah')} ${localNum(ayah)}'),
        ]),
        style: style,
      );
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.surahs, required this.surah, this.ayah});
  final List<SurahInfo> surahs;
  final int surah;

  /// Ayah to open at; defaults to the last-read ayah when it is in this surah.
  final int? ayah;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final SurahInfo _info = widget.surahs[widget.surah - 1];
  late final Future<(List<Ayah>, String?)> _data = _load();
  final _positions = ItemPositionsListener.create();
  final _listen = Listenable.merge([Settings.I, QuranStore.I.bookmarks, QuranStore.I.layout]);
  late int _top; // ayah number at the top of the viewport
  Timer? _saveTimer;
  List<Ayah> _ayahs = const [];
  List<int> _starts = const []; // chunk starts for the continuous layout

  bool get _continuous => QuranStore.I.layout.value == QuranLayout.continuous;

  @override
  void initState() {
    super.initState();
    final last = QuranStore.I.lastRead.value;
    _top = (widget.ayah ?? (last?.s == widget.surah ? last!.a : 1)).clamp(1, _info.ayahs);
    _positions.itemPositions.addListener(_onPositions);
  }

  Future<(List<Ayah>, String?)> _load() async {
    final n = widget.surah;
    final ayahs = Quran.surah(n);
    // Basmala header text comes from the data (1:1), never typed.
    final basmala = n == 1 || n == 9 ? null : (await Quran.surah(1)).first.ar;
    _ayahs = await ayahs;
    _starts = chunksOf(_ayahs);
    return (_ayahs, basmala);
  }

  // Item 0 is the header, items 1..body are ayahs (or chunks), then the prev/next item.
  int get _bodyCount => _continuous ? _starts.length : _ayahs.length;

  int _indexOf(int ayah) {
    final i = _continuous ? chunkOf(_starts, ayah) + 1 : ayah;
    return i == 1 ? 0 : i; // show the header when opening at the first item
  }

  int _ayahAt(int index) {
    final i = index.clamp(1, _bodyCount);
    return _continuous ? _ayahs[_starts[i - 1]].n : i;
  }

  // Runs every scroll frame: only tracks the top index; the write is debounced.
  void _onPositions() {
    var top = -1;
    for (final p in _positions.itemPositions.value) {
      if (p.itemTrailingEdge > 0 && (top < 0 || p.index < top)) top = p.index;
    }
    if (top < 0 || _ayahs.isEmpty) return;
    _top = _ayahAt(top);
    _saveTimer ??= Timer(const Duration(seconds: 1), _save);
  }

  void _save() {
    _saveTimer = null;
    QuranStore.I.setLastRead(widget.surah, _top);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _positions.itemPositions.removeListener(_onPositions);
    final s = widget.surah, a = _top;
    // Tree is locked during dispose; notify the index page's listeners after the frame.
    scheduleMicrotask(() => QuranStore.I.setLastRead(s, a));
    super.dispose();
  }

  void _goTo(int surah) => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ReaderPage(surahs: widget.surahs, surah: surah, ayah: 1)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _listen,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Settings.I.isAr
                ? Text(_info.ar, style: const TextStyle(fontFamily: quranFont))
                : Text(_info.en),
            actions: const [_LayoutButton(), SettingsButton()],
          ),
          body: FutureBuilder(
            future: _data,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text(t('تعذّر تحميل السورة', 'Could not load surah')));
              final d = snap.data;
              if (d == null) return const Center(child: CircularProgressIndicator());
              return _list(context, d.$1, d.$2);
            },
          ),
        ),
      );

  Widget _list(BuildContext context, List<Ayah> ayahs, String? basmala) {
    final fs = Settings.I.fontScale;
    final cs = Theme.of(context).colorScheme;
    // Styles built once per list rebuild (font scale / locale / bookmarks), shared by all items.
    final arStyle = TextStyle(fontFamily: quranFont, fontSize: 26 * fs, height: 2.1, color: cs.onSurface);
    final enStyle =
        Settings.I.isAr ? null : TextStyle(fontSize: 15 * fs, height: 1.5, color: cs.onSurfaceVariant);
    final layout = QuranStore.I.layout.value;
    final tafsirStyle = layout == QuranLayout.tafsir
        ? TextStyle(fontSize: 15 * fs, height: 1.7, color: cs.onSurfaceVariant)
        : null;
    final marks = QuranStore.I.bookmarks.value;
    final s = widget.surah;
    final body = _bodyCount;
    void onTap(Ayah a) => showAyahSheet(context, _info, a);
    return ScrollablePositionedList.builder(
      // New list per layout so the switch lands on the item holding the current top ayah.
      key: ValueKey(layout),
      itemCount: body + 2,
      initialScrollIndex: _indexOf(_top),
      itemPositionsListener: _positions,
      itemBuilder: (context, i) {
        if (i == 0) return _Header(info: _info, basmala: basmala, fontScale: fs);
        if (i > body) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Row(
              children: [
                if (s > 1) TextButton(onPressed: () => _goTo(s - 1), child: Text(t('السورة السابقة', 'Previous surah'))),
                const Spacer(),
                if (s < 114) FilledButton.tonal(onPressed: () => _goTo(s + 1), child: Text(t('السورة التالية', 'Next surah'))),
              ],
            ),
          );
        }
        if (layout == QuranLayout.continuous) {
          return _ChunkTile(
            ayahs: ayahs,
            start: _starts[i - 1],
            end: i < _starts.length ? _starts[i] : ayahs.length,
            style: arStyle,
            surah: s,
            marks: marks,
            markColor: cs.primary,
            onTap: onTap,
          );
        }
        final a = ayahs[i - 1];
        return _AyahTile(
          ayah: a,
          arStyle: arStyle,
          enStyle: enStyle,
          tafsirStyle: tafsirStyle,
          markColor: marks.contains('$s:${a.n}') ? cs.primary : null,
          onTap: () => onTap(a),
        );
      },
    );
  }
}

class _LayoutButton extends StatelessWidget {
  const _LayoutButton();

  static String label(QuranLayout l) => switch (l) {
        QuranLayout.ayah => t('آية آية', 'Ayah by ayah'),
        QuranLayout.continuous => t('متصل', 'Continuous'),
        QuranLayout.tafsir => t('مع التفسير', 'With tafsir'),
      };

  @override
  Widget build(BuildContext context) {
    final cur = QuranStore.I.layout.value;
    return PopupMenuButton<QuranLayout>(
      tooltip: '${t('طريقة العرض', 'Layout')}: ${label(cur)}',
      icon: Icon(switch (cur) {
        QuranLayout.ayah => Icons.view_agenda_outlined,
        QuranLayout.continuous => Icons.notes,
        QuranLayout.tafsir => Icons.menu_book_outlined,
      }),
      initialValue: cur,
      onSelected: QuranStore.I.setLayout,
      itemBuilder: (_) => [
        for (final l in QuranLayout.values) CheckedPopupMenuItem(value: l, checked: l == cur, child: Text(label(l))),
      ],
    );
  }
}

/// Continuous (mushaf-style) run of ayahs [start, end) as one justified paragraph; tap an ayah for its sheet.
class _ChunkTile extends StatefulWidget {
  const _ChunkTile({
    required this.ayahs,
    required this.start,
    required this.end,
    required this.style,
    required this.surah,
    required this.marks,
    required this.markColor,
    required this.onTap,
  });
  final List<Ayah> ayahs;
  final int start, end, surah;
  final TextStyle style;
  final Set<String> marks;
  final Color markColor;
  final void Function(Ayah) onTap;

  @override
  State<_ChunkTile> createState() => _ChunkTileState();
}

class _ChunkTileState extends State<_ChunkTile> {
  late List<TapGestureRecognizer> _taps = _make();

  // One recognizer per ayah, alive as long as this chunk is built; reads widget at tap time.
  List<TapGestureRecognizer> _make() => [
        for (var i = widget.start; i < widget.end; i++)
          TapGestureRecognizer()..onTap = () => widget.onTap(widget.ayahs[i]),
      ];

  void _dispose() {
    for (final r in _taps) {
      r.dispose();
    }
  }

  @override
  void didUpdateWidget(_ChunkTile old) {
    super.didUpdateWidget(old);
    if (old.ayahs != widget.ayahs || old.start != widget.start || old.end != widget.end) {
      _dispose();
      _taps = _make();
    }
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final marked = TextStyle(color: w.markColor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text.rich(
        TextSpan(children: [
          for (var i = w.start; i < w.end; i++) ...[
            TextSpan(
              text: w.ayahs[i].text,
              recognizer: _taps[i - w.start],
              style: w.marks.contains('${w.surah}:${w.ayahs[i].n}') ? marked : null,
            ),
            const TextSpan(text: ' '),
          ],
        ]),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        style: w.style,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.info, required this.basmala, required this.fontScale});
  final SurahInfo info;
  final String? basmala;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // The inherited body height (1.43) clips Amiri Quran's deep descenders into the line below.
          // Measured over all 114 names: height 3.0 keeps the deepest (Al-Hajj) 2px inside the box;
          // the first-ascent flag drops the extra space it would add above.
          Text(info.ar,
              textDirection: TextDirection.rtl,
              textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false),
              style: TextStyle(
                  fontFamily: quranFont, fontSize: 30 * fontScale, height: 3.0, color: theme.colorScheme.primary)),
          Text('${info.en} · ${info.meaning}', style: theme.textTheme.bodySmall),
          if (basmala != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(basmala!,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: quranFont, fontSize: 24 * fontScale, height: 2)),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

class _AyahTile extends StatelessWidget {
  const _AyahTile(
      {required this.ayah, required this.arStyle, this.enStyle, this.tafsirStyle, this.markColor, required this.onTap});
  final Ayah ayah;
  final TextStyle arStyle;
  final TextStyle? enStyle;

  /// Non-null in the "with tafsir" layout.
  final TextStyle? tafsirStyle;

  /// Non-null when bookmarked.
  final Color? markColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (markColor != null)
                Align(alignment: Alignment.topLeft, child: Icon(Icons.bookmark, size: 18, color: markColor)),
              Text(ayah.text, textDirection: TextDirection.rtl, style: arStyle),
              if (tafsirStyle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(ayah.tafsir, textDirection: TextDirection.rtl, style: tafsirStyle),
                ),
              if (enStyle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(ayah.en, textDirection: TextDirection.ltr, style: enStyle),
                ),
            ],
          ),
        ),
      );
}

void showAyahSheet(BuildContext context, SurahInfo info, Ayah ayah) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AyahSheet(info: info, ayah: ayah),
    );

class _AyahSheet extends StatelessWidget {
  const _AyahSheet({required this.info, required this.ayah});
  final SurahInfo info;
  final Ayah ayah;

  @override
  Widget build(BuildContext context) {
    final fs = Settings.I.fontScale;
    final theme = Theme.of(context);
    final label = theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary);
    final ref = '${Settings.I.isAr ? info.ar : info.en} ${info.n}:${ayah.n}';
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Center(child: SurahRef(info: info, ayah: ayah.n, style: theme.textTheme.titleSmall)),
          const SizedBox(height: 8),
          Text(ayah.text,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: quranFont, fontSize: 26 * fs, height: 2.1)),
          const Divider(height: 24),
          Text(t('التفسير الميسر', 'Tafsir al-Muyassar (Arabic)'), style: label),
          const SizedBox(height: 4),
          Text(ayah.tafsir, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 17 * fs, height: 1.7)),
          const Divider(height: 24),
          Text('Saheeh International', textDirection: TextDirection.ltr, style: label),
          const SizedBox(height: 4),
          Text(ayah.en, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 15 * fs, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ValueListenableBuilder(
                valueListenable: QuranStore.I.bookmarks,
                builder: (context, set, _) {
                  final on = set.contains('${info.n}:${ayah.n}');
                  return TextButton.icon(
                    onPressed: () => QuranStore.I.toggleBookmark(info.n, ayah.n),
                    icon: Icon(on ? Icons.bookmark : Icons.bookmark_border),
                    label: Text(on ? t('إزالة العلامة', 'Remove bookmark') : t('حفظ علامة', 'Bookmark')),
                  );
                },
              ),
              TextButton.icon(
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Clipboard.setData(ClipboardData(text: '${ayah.ar}\n[$ref]'));
                  Navigator.of(context).pop();
                  messenger.showSnackBar(SnackBar(content: Text(t('تم النسخ', 'Copied'))));
                },
                icon: const Icon(Icons.copy),
                label: Text(t('نسخ', 'Copy')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
