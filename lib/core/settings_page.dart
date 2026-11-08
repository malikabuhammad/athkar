import 'package:material_ui/material_ui.dart';

import '../reminders/reminders_page.dart';
import 'settings.dart';
import 'strings.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.settings_outlined),
        tooltip: t('الإعدادات', 'Settings'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
      );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Local value while dragging so the whole app doesn't rebuild every frame.
  double _scale = Settings.I.fontScale;

  @override
  Widget build(BuildContext context) {
    final s = Settings.I;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(t('الإعدادات', 'Settings'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t('اللغة', 'Language'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ar', label: Text('العربية')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {s.locale},
              onSelectionChanged: (v) => s.setLocale(v.first),
            ),
            const SizedBox(height: 24),
            Text(t('المظهر', 'Theme'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(t('النظام', 'System'))),
                ButtonSegment(value: ThemeMode.light, label: Text(t('فاتح', 'Light'))),
                ButtonSegment(value: ThemeMode.dark, label: Text(t('داكن', 'Dark'))),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
            const SizedBox(height: 24),
            Text(t('حجم الخط', 'Font size'), style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: _scale,
              min: Settings.minFontScale,
              max: Settings.maxFontScale,
              divisions: 8,
              label: _scale.toStringAsFixed(1),
              onChanged: (v) => setState(() => _scale = v),
              onChangeEnd: s.setFontScale,
            ),
            Text(
              'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 22 * _scale, height: 1.8),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_outlined),
              title: Text(t('التذكيرات', 'Reminders')),
              subtitle: Text(t('أذكار الصباح والمساء', 'Morning and evening azkar')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const RemindersPage())),
            ),
            const SizedBox(height: 24),
            Text(t('حول التطبيق / المصادر', 'About / sources'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (ar, en) in const [
              (
                'نص القرآن: مشروع تنزيل (tanzil.net)، الرسم العثماني، رخصة CC BY 3.0 — يُعرض كما هو دون تعديل',
                'Quran text: Tanzil Project (tanzil.net), Uthmani text, CC BY 3.0 — shown verbatim',
              ),
              (
                'التفسير: التفسير الميسر (مجمع الملك فهد لطباعة المصحف الشريف)',
                'Tafsir: التفسير الميسر (King Fahd Complex for the Printing of the Holy Quran)',
              ),
              ('الترجمة الإنجليزية: Saheeh International', 'English translation: Saheeh International'),
              ('الأذكار: صحيح البخاري وصحيح مسلم', 'Azkar: Sahih al-Bukhari and Sahih Muslim'),
              ('الخط: Amiri Quran (رخصة SIL OFL)', 'Font: Amiri Quran (SIL OFL)'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(t(ar, en)),
              ),
          ],
        ),
      ),
    );
  }
}
