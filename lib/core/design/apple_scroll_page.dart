import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'apple_chrome.dart';
import 'apple_accessibility.dart';

/// A navigation title and its content share one scroll position. The framework
/// owns title collapse, scroll-edge material and overscroll/refresh physics.
class AppleScrollPage extends StatelessWidget {
  const AppleScrollPage({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.leading,
    this.bottom,
    this.onRefresh,
    this.grouped = false,
    this.largeTitle = true,
    this.automaticallyImplyLeading = true,
    this.controller,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? trailing, leading;
  final PreferredSizeWidget? bottom;
  final Future<void> Function()? onRefresh;
  final bool grouped, largeTitle, automaticallyImplyLeading;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final tokens = appleTokensOf(context)!;
    final background = grouped
        ? tokens.groupedBackground
        : tokens.cardBackground;
    final opaque =
        MediaQuery.highContrastOf(context) ||
        AppleAccessibility.reduceTransparencyOf(context);
    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: largeTitle
          ? null
          : CupertinoNavigationBar(
              middle: Text(title),
              leading: leading,
              trailing: trailing,
              automaticallyImplyLeading: automaticallyImplyLeading,
              backgroundColor: opaque
                  ? background
                  : background.withValues(alpha: .9),
              border: null,
              enableBackgroundFilterBlur: !opaque,
              transitionBetweenRoutes: false,
            ),
      child: Builder(
        builder: (context) => CustomScrollView(
          controller: controller,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            if (!largeTitle)
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).top),
              ),
            if (largeTitle)
              CupertinoSliverNavigationBar(
                largeTitle: Text(title),
                alwaysShowMiddle: false,
                leading: leading,
                trailing: trailing,
                automaticallyImplyLeading: automaticallyImplyLeading,
                backgroundColor: opaque
                    ? background
                    : background.withValues(alpha: .9),
                border: null,
                enableBackgroundFilterBlur: !opaque,
                // Explicit toolbar controls are not shared Hero elements.
                transitionBetweenRoutes: false,
                stretch: !MediaQuery.disableAnimationsOf(context),
                bottom: bottom,
                bottomMode: bottom == null
                    ? null
                    : NavigationBarBottomMode.always,
              ),
            if (onRefresh != null)
              CupertinoSliverRefreshControl(onRefresh: onRefresh),
            for (final sliver in slivers)
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final inset = math.max(
                    0.0,
                    (constraints.crossAxisExtent - 760) / 2,
                  );
                  return SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    sliver: sliver,
                  );
                },
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 24 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
