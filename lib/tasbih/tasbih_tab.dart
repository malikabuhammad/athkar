import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/settings.dart';
import '../core/settings_page.dart';
import '../core/strings.dart';

/// Counter state; target 0 means unlimited.
class TasbihCounter {
  TasbihCounter(this.prefs)
      : count = ValueNotifier(prefs.getInt('tasbih_count') ?? 0),
        target = ValueNotifier(prefs.getInt('tasbih_target') ?? 33),
        rounds = ValueNotifier(prefs.getInt('tasbih_rounds') ?? 0);

  final SharedPreferences prefs;
  final ValueNotifier<int> count;
  final ValueNotifier<int> target;
  final ValueNotifier<int> rounds;

  /// Returns true when this tap completed a round.
  bool tap() {
    final t = target.value;
    // After a completed round the full count stays visible; the next tap starts a new round.
    count.value = t > 0 && count.value >= t ? 1 : count.value + 1;
    prefs.setInt('tasbih_count', count.value);
    if (t > 0 && count.value == t) {
      rounds.value++;
      prefs.setInt('tasbih_rounds', rounds.value);
      return true;
    }
    return false;
  }

  void setTarget(int v) {
    target.value = v;
    prefs.setInt('tasbih_target', v);
  }

  void reset() {
    count.value = 0;
    rounds.value = 0;
    prefs.setInt('tasbih_count', 0);
    prefs.setInt('tasbih_rounds', 0);
  }

  void dispose() {
    count.dispose();
    target.dispose();
    rounds.dispose();
  }
}

class TasbihTab extends StatefulWidget {
  const TasbihTab({super.key});

  @override
  State<TasbihTab> createState() => _TasbihTabState();
}

class _TasbihTabState extends State<TasbihTab> {
  final _c = TasbihCounter(Settings.I.prefs);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() => _c.tap() ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('تصفير العداد؟', 'Reset counter?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('إلغاء', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('تصفير', 'Reset'))),
        ],
      ),
    );
    if (ok == true) _c.reset();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('التسبيح', 'Tasbih')),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: t('تصفير', 'Reset'),
            onPressed: _confirmReset,
          ),
          const SettingsButton(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _c.target,
              builder: (context, target, _) => SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 33, label: Text('33')),
                  ButtonSegment(value: 100, label: Text('100')),
                  ButtonSegment(value: 0, label: Text('∞')),
                ],
                selected: {target},
                onSelectionChanged: (v) => _c.setTarget(v.first),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: _c.rounds,
              builder: (context, r, _) => Text(
                '${t('الدورات', 'Rounds')}: $r',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(32),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('tasbih_tap'),
                  onTap: _tap,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: RepaintBoundary(
                          child: ValueListenableBuilder<int>(
                            valueListenable: _c.target,
                            builder: (context, target, _) => ValueListenableBuilder<int>(
                              valueListenable: _c.count,
                              builder: (context, n, _) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: target > 0 ? (n / target).clamp(0.0, 1.0) : 0,
                                    strokeWidth: 10,
                                    backgroundColor: scheme.surfaceContainerHighest,
                                  ),
                                  Center(
                                    child: FittedBox(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                          '$n',
                                          style: TextStyle(
                                            fontSize: 96,
                                            fontWeight: FontWeight.w300,
                                            color: scheme.primary,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
