import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';

void main() {
  test('website theme presets expose four colours plus neutral', () {
    expect(
      ThemeColour.values.map((e) => e.id),
      containsAll(<String>['azure', 'pink', 'mint', 'orange', 'none']),
    );
  });

  test('theme mode round trips', () {
    expect(
      ThemeModePreference.fromId(ThemeModePreference.dark.id),
      ThemeModePreference.dark,
    );
  });
}
