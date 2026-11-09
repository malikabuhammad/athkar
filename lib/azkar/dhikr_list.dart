import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/settings.dart';
import '../core/settings_page.dart';
import '../core/strings.dart';
import 'azkar_data.dart';

class DhikrListPage extends StatelessWidget {
  const DhikrListPage({super.key, required this.title, required this.items});

  final String title;
  final List<Dhikr> items;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: t('تصفير العدادات', 'Reset counters'),
              onPressed: () => resetProgress(items),
            ),
            const SettingsButton(),
          ],
        ),
        body: DhikrList(items: items),
      );
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key, required this.all});

  final List<Dhikr> all;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Set<String>>(
        valueListenable: Favorites.notifier,
        builder: (context, favs, _) => DhikrListPage(
          title: t('المفضلة', 'Favorites'),
          items: [for (final d in all) if (favs.contains(d.id)) d],
        ),
      );
}

class DhikrList extends StatelessWidget {
  const DhikrList({super.key, required this.items});

  final List<Dhikr> items;

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: items.length,
        itemBuilder: (context, i) => DhikrCard(key: ValueKey(items[i].id), d: items[i]),
      );
}

String sourceOf(Dhikr d) {
  final book = switch (d.book) {
    'bukhari' => t('صحيح البخاري', 'Sahih al-Bukhari'),
    'muslim' => t('صحيح مسلم', 'Sahih Muslim'),
    final b => b ?? '',
  };
  return d.number == null ? book : '$book ${t('رقم', 'no.')} ${d.number}';
}

class DhikrCard extends StatelessWidget {
  const DhikrCard({super.key, required this.d});

  final Dhikr d;

  void _tap() {
    if (progressOf(d).value >= d.count) return;
    countTap(d) ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
  }

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: '${d.ar}\n\n${sourceOf(d)}'));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t('تم النسخ', 'Copied'))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isAr = Settings.I.isAr;
    final note = isAr ? d.noteAr ?? d.noteEn : d.noteEn ?? d.noteAr;
    final source = sourceOf(d);
    final small = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    // Static content is built once and handed to the builder as `child`;
    // a tap only rebuilds the card frame and the counter.
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          d.ar,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Quran', fontSize: 22 * Settings.I.fontScale, height: 2.0),
        ),
        if (d.en != null)
          if (isAr) _Translation(text: d.en!) else _english(d.en!, theme),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note, style: small, textAlign: TextAlign.center),
        ],
        if (source.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(source, style: small, textAlign: TextAlign.center),
        ],
      ],
    );

    return ValueListenableBuilder<int>(
      valueListenable: progressOf(d),
      child: content,
      builder: (context, n, child) {
        final done = n >= d.count;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          clipBehavior: Clip.antiAlias,
          color: done ? scheme.primaryContainer : null,
          child: InkWell(
            onTap: _tap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  child!,
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _FavButton(id: d.id),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined),
                        tooltip: t('نسخ', 'Copy'),
                        onPressed: () => _copy(context),
                      ),
                      const Spacer(),
                      done
                          ? FilledButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.check),
                              label: Text('${d.count}/${d.count}'),
                            )
                          : FilledButton.tonal(
                              onPressed: _tap,
                              style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
                              child: Text('$n/${d.count}'),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _english(String en, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(en, style: theme.textTheme.bodyMedium, textDirection: TextDirection.ltr),
      );
}

class _Translation extends StatefulWidget {
  const _Translation({required this.text});

  final String text;

  @override
  State<_Translation> createState() => _TranslationState();
}

class _TranslationState extends State<_Translation> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
              label: const Text('الترجمة'),
            ),
          ),
          if (_open) DhikrCard._english(widget.text, Theme.of(context)),
        ],
      );
}

class _FavButton extends StatelessWidget {
  const _FavButton({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Set<String>>(
        valueListenable: Favorites.notifier,
        builder: (context, favs, _) {
          final fav = favs.contains(id);
          return IconButton(
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
            color: fav ? Theme.of(context).colorScheme.primary : null,
            tooltip: t('المفضلة', 'Favorite'),
            onPressed: () => Favorites.toggle(id),
          );
        },
      );
}
