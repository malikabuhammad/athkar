import 'package:material_ui/material_ui.dart';

import '../core/settings.dart';
import '../core/settings_page.dart';
import '../core/strings.dart';
import 'azkar_data.dart';
import 'dhikr_list.dart';

class AzkarTab extends StatelessWidget {
  const AzkarTab({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AzkarCategory>>(
        future: loadAzkar(),
        builder: (context, snap) {
          final cats = snap.data;
          final all = cats == null ? const <Dhikr>[] : [for (final c in cats) ...c.items];
          return Scaffold(
            appBar: AppBar(
              title: Text(t('الأذكار', 'Azkar')),
              actions: [
                if (cats != null)
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: t('بحث', 'Search'),
                    onPressed: () => _push(context, AzkarSearchPage(all: all)),
                  ),
                const SettingsButton(),
              ],
            ),
            body: cats != null
                ? _Home(cats: cats, all: all)
                : Center(
                    child: snap.hasError
                        ? Text(t('تعذّر تحميل الأذكار', 'Could not load azkar'))
                        : const CircularProgressIndicator(),
                  ),
          );
        },
      );
}

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class _Home extends StatelessWidget {
  const _Home({required this.cats, required this.all});

  final List<AzkarCategory> cats;
  final List<Dhikr> all;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Set<String>>(
        valueListenable: Favorites.notifier,
        builder: (context, favs, _) {
          final hasFavs = favs.isNotEmpty;
          return ListView.builder(
            itemCount: cats.length + (hasFavs ? 1 : 0),
            itemBuilder: (context, i) {
              if (hasFavs && i == 0) {
                return ListTile(
                  leading: const Icon(Icons.favorite),
                  title: Text(t('المفضلة', 'Favorites')),
                  trailing: Text('${favs.length}'),
                  onTap: () => _push(context, FavoritesPage(all: all)),
                );
              }
              final c = cats[i - (hasFavs ? 1 : 0)];
              final title = Settings.I.isAr ? c.ar : c.en;
              return ListTile(
                leading: const Icon(Icons.auto_stories_outlined),
                title: Text(title),
                trailing: Text('${c.items.length}'),
                onTap: () => _push(context, DhikrListPage(title: title, items: c.items)),
              );
            },
          );
        },
      );
}

class AzkarSearchPage extends StatefulWidget {
  const AzkarSearchPage({super.key, required this.all});

  final List<Dhikr> all;

  @override
  State<AzkarSearchPage> createState() => _AzkarSearchPageState();
}

class _AzkarSearchPageState extends State<AzkarSearchPage> {
  final _results = ValueNotifier<List<Dhikr>>(const []);

  @override
  void dispose() {
    _results.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: t('ابحث في الأذكار', 'Search azkar'), border: InputBorder.none),
            onChanged: (q) => _results.value = searchAzkar(widget.all, q),
          ),
        ),
        body: ValueListenableBuilder<List<Dhikr>>(
          valueListenable: _results,
          builder: (context, items, _) => DhikrList(items: items),
        ),
      );
}
