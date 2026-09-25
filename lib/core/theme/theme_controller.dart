import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/design_style.dart';
import 'app_theme.dart';

class ThemeState {
  const ThemeState({
    this.colour = ThemeColour.azure,
    this.mode = ThemeModePreference.auto,
    this.style = DesignStyle.material,
  });
  final ThemeColour colour;
  final ThemeModePreference mode;

  /// 界面风格：Material 还是一套 Apple 语言的排版与动效。
  final DesignStyle style;
}

class ThemeController extends Notifier<ThemeState> {
  static const colourKey = 'ycomm_theme_colour';
  static const modeKey = 'ycomm_theme_mode';
  static const styleKey = 'ycomm_theme_style';

  @override
  ThemeState build() => const ThemeState();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ThemeState(
      colour: ThemeColour.fromId(prefs.getString(colourKey)),
      mode: ThemeModePreference.fromId(prefs.getString(modeKey)),
      // 没存过偏好时按平台给默认值（Apple 平台用 Apple 风格），
      // 但**不写回 prefs**——这样用户第一次手动切换前，行为始终跟随平台。
      style: DesignStyle.resolve(prefs.getString(styleKey)),
    );
  }

  Future<void> setColour(ThemeColour colour) async {
    state = ThemeState(colour: colour, mode: state.mode, style: state.style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(colourKey, colour.id);
  }

  Future<void> setMode(ThemeModePreference mode) async {
    state = ThemeState(colour: state.colour, mode: mode, style: state.style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(modeKey, mode.id);
  }

  Future<void> setStyle(DesignStyle style) async {
    state = ThemeState(colour: state.colour, mode: state.mode, style: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(styleKey, style.id);
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeState>(
  ThemeController.new,
);
