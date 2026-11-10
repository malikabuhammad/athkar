import 'package:material_ui/material_ui.dart';

import '../core/settings.dart';
import '../core/strings.dart';
import 'reminders.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final _prefs = Settings.I.prefs;

  Future<void> _toggle(Reminder r, bool on) async {
    final ok = await Reminders.setEnabled(r, on);
    if (!mounted) return;
    setState(() {});
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('لم يُسمح بالإشعارات. فعّلها من إعدادات الجهاز.',
            'Notifications are not allowed. Enable them in your device settings.')),
      ));
    }
  }

  Future<void> _pickTime(Reminder r) async {
    final picked = await showTimePicker(context: context, initialTime: r.timeIn(_prefs));
    if (picked == null) return;
    await Reminders.setTime(r, picked);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('التذكيرات', 'Reminders'))),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (!Reminders.supported)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(t('التذكيرات متاحة في تطبيق الجوال فقط.', 'Reminders are only available in the mobile app.')),
              ),
            for (final r in Reminder.values)
              ListTile(
                enabled: Reminders.supported,
                leading: Icon(r == Reminder.morning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined),
                title: Text(r.label),
                subtitle: Text(r.timeIn(_prefs).format(context)),
                onTap: () => _pickTime(r),
                trailing: Switch(
                  value: r.enabledIn(_prefs),
                  onChanged: Reminders.supported ? (v) => _toggle(r, v) : null,
                ),
              ),
          ],
        ),
      );
}
