import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings._();
  static final Settings I = Settings._();

  late final SharedPreferences prefs;

  String locale = 'ar';
  ThemeMode themeMode = ThemeMode.system;
  double fontScale = 1.0;

  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.6;

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    locale = prefs.getString('locale') ?? 'ar';
    themeMode = ThemeMode.values[(prefs.getInt('themeMode') ?? 0).clamp(0, 2)];
    fontScale = (prefs.getDouble('fontScale') ?? 1.0)
        .clamp(minFontScale, maxFontScale);
  }

  bool get isAr => locale == 'ar';

  void setLocale(String v) {
    locale = v;
    prefs.setString('locale', v);
    notifyListeners();
  }

  void setThemeMode(ThemeMode v) {
    themeMode = v;
    prefs.setInt('themeMode', v.index);
    notifyListeners();
  }

  void setFontScale(double v) {
    fontScale = v.clamp(minFontScale, maxFontScale);
    prefs.setDouble('fontScale', fontScale);
    notifyListeners();
  }
}
