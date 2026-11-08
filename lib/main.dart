import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:material_ui/material_ui.dart';

import 'azkar/azkar_tab.dart';
import 'core/settings.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'prayer/prayer_tab.dart';
import 'quran/quran_tab.dart';
import 'reminders/reminders.dart';
import 'tasbih/tasbih_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.I.load();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}
  }
  runApp(const App());
  // After the first frame; init() catches its own errors, so it can't break startup.
  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(Reminders.init()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Settings.I,
        builder: (context, _) => MaterialApp(
          title: 'Azkar',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: Settings.I.themeMode,
          locale: Locale(Settings.I.locale),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const HomePage(),
        ),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  final _visited = [true, false, false, false];

  static Widget _tab(int i) => switch (i) {
        0 => const AzkarTab(),
        1 => const QuranTab(),
        2 => const TasbihTab(),
        _ => const PrayerTab(),
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Settings.I,
        builder: (context, _) => Scaffold(
          // Keyed by locale so const tab subtrees re-run t() after a language switch.
          body: KeyedSubtree(
            key: ValueKey(Settings.I.locale),
            child: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < 4; i++)
                  TickerMode(
                    enabled: i == _index,
                    child: _visited[i] ? _tab(i) : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() {
              _index = i;
              _visited[i] = true;
            }),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.auto_stories_outlined),
                selectedIcon: const Icon(Icons.auto_stories),
                label: t('الأذكار', 'Azkar'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: t('القرآن', 'Quran'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.touch_app_outlined),
                selectedIcon: const Icon(Icons.touch_app),
                label: t('التسبيح', 'Tasbih'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.access_time_outlined),
                selectedIcon: const Icon(Icons.access_time_filled),
                label: t('الصلاة', 'Prayer'),
              ),
            ],
          ),
        ),
      );
}
