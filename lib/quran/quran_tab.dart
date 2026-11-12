import 'package:material_ui/material_ui.dart';

import '../core/settings_page.dart';
import '../core/strings.dart';
import 'quran_data.dart';
import 'reader_page.dart';
import 'search_page.dart';

class QuranTab extends StatefulWidget {
  const QuranTab({super.key});

  @override
  State<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<QuranTab> {
  List<SurahInfo>? _all;
  List<SurahInfo> _shown = const [];
  bool _filtered = false;

  @override
  void initState() {
    super.initState();
    Quran.surahs().then((l) {
      if (mounted) setState(() => _all = _shown = l);
    });
  }

  void _filter(String v) {
    final all = _all;
    if (all == null) return;
    final q = normalizeArabic(v).toLowerCase();
    setState(() {
      _filtered = q.isNotEmpty;
      _shown = q.isEmpty ? all : all.where((s) => '${s.n}' == q || s.key.contains(q)).toList();
    });
  }

  void _push(Widget Function(List<SurahInfo>) page) {
    final all = _all;
    if (all != null) Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page(all)));
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('القرآن', 'Quran')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: t('بحث', 'Search'),
            onPressed: () => _push((s) => SearchPage(surahs: s)),
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: t('العلامات', 'Bookmarks'),
            onPressed: () => _push((s) => BookmarksPage(surahs: s)),
          ),
          const SettingsButton(),
        ],
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    onChanged: _filter,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.filter_list),
                      hintText: t('اسم السورة أو رقمها', 'Surah name or number'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _shown.length + 1,
                    itemBuilder: (context, i) => i == 0
                        ? (_filtered ? const SizedBox.shrink() : _ContinueCard(surahs: all))
                        : _SurahTile(info: _shown[i - 1], surahs: all),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.surahs});
  final List<SurahInfo> surahs;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: QuranStore.I.lastRead,
        builder: (context, last, _) {
          if (last == null || last.s < 1 || last.s > surahs.length) return const SizedBox.shrink();
          final info = surahs[last.s - 1];
          return Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(t('متابعة القراءة', 'Continue reading')),
              subtitle: SurahRef(info: info, ayah: last.a),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openReader(context, surahs, last.s, ayah: last.a),
            ),
          );
        },
      );
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.info, required this.surahs});
  final SurahInfo info;
  final List<SurahInfo> surahs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.secondaryContainer,
        child: Text(localNum(info.n), style: TextStyle(color: cs.onSecondaryContainer)),
      ),
      title: Text('${info.en} · ${info.meaning}'),
      subtitle: Text(
        '${localNum(info.ayahs)} ${t('آية', 'ayahs')} · ${info.meccan ? t('مكية', 'Meccan') : t('مدنية', 'Medinan')}',
      ),
      trailing: Text(info.ar,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: quranFont, fontSize: 20, color: cs.primary)),
      onTap: () => openReader(context, surahs, info.n),
    );
  }
}

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key, required this.surahs});
  final List<SurahInfo> surahs;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('العلامات', 'Bookmarks'))),
        body: ValueListenableBuilder(
          valueListenable: QuranStore.I.bookmarks,
          builder: (context, set, _) {
            if (set.isEmpty) return Center(child: Text(t('لا توجد علامات بعد', 'No bookmarks yet')));
            final keys = [
              for (final k in set)
                if (k.split(':') case [final s, final a]) (s: int.tryParse(s) ?? 0, a: int.tryParse(a) ?? 0),
            ].where((k) => k.s >= 1 && k.s <= surahs.length && k.a >= 1 && k.a <= surahs[k.s - 1].ayahs).toList()
              ..sort((x, y) => x.s != y.s ? x.s - y.s : x.a - y.a);
            return ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, i) =>
                  _BookmarkTile(key: ValueKey(keys[i]), surahs: surahs, s: keys[i].s, a: keys[i].a),
            );
          },
        ),
      );
}

class _BookmarkTile extends StatefulWidget {
  const _BookmarkTile({super.key, required this.surahs, required this.s, required this.a});
  final List<SurahInfo> surahs;
  final int s, a;

  @override
  State<_BookmarkTile> createState() => _BookmarkTileState();
}

class _BookmarkTileState extends State<_BookmarkTile> {
  late final Future<String> _snippet = Quran.surah(widget.s).then((l) => l[widget.a - 1].ar);

  @override
  Widget build(BuildContext context) {
    final info = widget.surahs[widget.s - 1];
    return ListTile(
      title: SurahRef(info: info, ayah: widget.a),
      subtitle: FutureBuilder(
        future: _snippet,
        builder: (context, snap) => Text(
          snap.data ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: quranFont, fontSize: 18),
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.bookmark_remove_outlined),
        tooltip: t('إزالة', 'Remove'),
        onPressed: () => QuranStore.I.toggleBookmark(widget.s, widget.a),
      ),
      onTap: () => openReader(context, widget.surahs, widget.s, ayah: widget.a),
    );
  }
}
