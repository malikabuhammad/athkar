import 'package:material_ui/material_ui.dart';

const _seed = Color(0xFF2E7D6B); // calm teal-green

ThemeData buildTheme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
      appBarTheme: const AppBarTheme(centerTitle: true),
    );

final lightTheme = buildTheme(Brightness.light);
final darkTheme = buildTheme(Brightness.dark);
