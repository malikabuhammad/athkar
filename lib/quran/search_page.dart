import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import 'quran_data.dart';
import 'reader_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.surahs});
  final List<SurahInfo> surahs;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<SearchLine>? _lines;
  String _query = '';
  SearchResult _result = const SearchResult(0, [], 0);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Quran.searchLines().then((l) {
      if (mounted) setState(() => _run(_lines = l));
    });
  }

  void _run(List<SearchLine> lines) => _result = searchQuran(lines, _query);

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _query = v;
      final lines = _lines;
      if (lines != null) setState(() => _run(lines));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: TextField(
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: t('ابحث في القرآن', 'Search the Quran (Arabic)'),
            ),
          ),
        ),
        body: _body(context),
      );

  Widget _body(BuildContext context) {
    if (_lines == null) return const Center(child: CircularProgressIndicator());
    if (normalizeArabic(_query).isEmpty) {
      return _message(Icons.search, t('اكتب كلمة أو جزءاً من آية', 'Type an Arabic word or part of an ayah'));
    }
    final r = _result;
    if (r.total == 0) return _message(Icons.search_off, t('لا توجد نتائج', 'No results'));
    return ListView.builder(
      itemCount: r.hits.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          final capped = r.total > r.hits.length;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '${t('عدد النتائج', 'Results')}: ${localNum(r.total)}'
              '${capped ? t(' (يُعرض أول ${localNum(r.hits.length)})', ' (showing first ${r.hits.length})') : ''}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          );
        }
        final (line, at) = r.hits[i - 1];
        return _ResultTile(line: line, at: at, length: r.length, surahs: widget.surahs);
      },
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 48), const SizedBox(height: 8), Text(text)],
        ),
      );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.line, required this.at, required this.length, required this.surahs});
  final SearchLine line;
  final int at, length;
  final List<SurahInfo> surahs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = surahs[line.s - 1];
    final text = line.text;
    return ListTile(
      title: Text.rich(
        TextSpan(children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: text.substring(at, at + length),
            style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, backgroundColor: cs.primaryContainer),
          ),
          TextSpan(text: text.substring(at + length)),
        ]),
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 17, height: 1.6),
      ),
      subtitle: SurahRef(info: info, ayah: line.a),
      onTap: () => openReader(context, surahs, line.s, ayah: line.a),
    );
  }
}
