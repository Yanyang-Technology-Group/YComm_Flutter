import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, ThemeData;
import 'package:flutter_localizations/flutter_localizations.dart';

/// ThemeData is shared color/typography data only. CupertinoApp owns navigation,
/// selection menus, scrolling and page chrome in Apple mode.
class AppleApp extends StatelessWidget {
  const AppleApp({
    super.key,
    required this.theme,
    required this.home,
    this.builder,
    this.navigatorKey,
  });
  final GlobalKey<NavigatorState>? navigatorKey;
  final ThemeData theme;
  final Widget home;
  final TransitionBuilder? builder;
  @override
  Widget build(BuildContext context) => CupertinoApp(
    navigatorKey: navigatorKey,
    title: '晏阳社区',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: const [
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
    ],
    theme: CupertinoThemeData(
      brightness: theme.brightness,
      primaryColor: theme.colorScheme.primary,
      primaryContrastingColor: theme.colorScheme.onPrimary,
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      textTheme: CupertinoTextThemeData(
        textStyle: theme.textTheme.bodyLarge!,
        navTitleTextStyle: theme.textTheme.titleMedium!,
        navLargeTitleTextStyle: theme.textTheme.headlineLarge!,
      ),
    ),
    scrollBehavior: const _AppleScrollBehavior(),
    builder: (context, child) => Theme(
      data: theme,
      child: DefaultTextStyle(
        style: theme.textTheme.bodyLarge!,
        child: IconTheme(
          data: IconThemeData(color: theme.colorScheme.primary, size: 22),
          child: Builder(
            builder: (context) =>
                builder?.call(context, child) ??
                child ??
                const SizedBox.shrink(),
          ),
        ),
      ),
    ),
    home: home,
  );
}

class _AppleScrollBehavior extends CupertinoScrollBehavior {
  const _AppleScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
