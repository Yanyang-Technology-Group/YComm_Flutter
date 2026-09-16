import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeState {
  const ThemeState({
    this.colour = ThemeColour.azure,
    this.mode = ThemeModePreference.auto,
  });
  final ThemeColour colour;
  final ThemeModePreference mode;
}

class ThemeController extends Notifier<ThemeState> {
  static const colourKey = 'ycomm_theme_colour';
  static const modeKey = 'ycomm_theme_mode';

  @override
  ThemeState build() => const ThemeState();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ThemeState(
      colour: ThemeColour.fromId(prefs.getString(colourKey)),
      mode: ThemeModePreference.fromId(prefs.getString(modeKey)),
    );
  }

  Future<void> setColour(ThemeColour colour) async {
    state = ThemeState(colour: colour, mode: state.mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(colourKey, colour.id);
  }

  Future<void> setMode(ThemeModePreference mode) async {
    state = ThemeState(colour: state.colour, mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(modeKey, mode.id);
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeState>(
  ThemeController.new,
);
