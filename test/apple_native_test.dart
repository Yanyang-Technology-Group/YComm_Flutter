import 'package:flutter/gestures.dart';
import 'package:ycomm_client/features/shell/desktop_title_bar.dart';
import 'package:ycomm_client/core/design/design_style.dart';
import 'package:flutter/services.dart';
import 'package:ycomm_client/core/design/apple_app.dart';
import 'package:ycomm_client/core/design/apple_theme.dart';
import 'package:ycomm_client/core/design/adaptive.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/core/widgets/design.dart';
import 'package:ycomm_client/features/profile/appearance_page.dart';
import 'package:ycomm_client/features/profile/settings_page.dart';
import 'package:ycomm_client/features/profile/about_page.dart';
import 'package:ycomm_client/features/auth/login_page.dart';
import 'package:ycomm_client/features/auth/register_page.dart';
import 'package:ycomm_client/features/auth/forgot_password_page.dart';
import 'package:ycomm_client/features/forum/compose_page.dart';
import 'package:ycomm_client/features/forum/topic_page.dart';
import 'package:ycomm_client/features/forum/my_posts_page.dart';
import 'package:ycomm_client/features/search/search_page.dart';
import 'package:ycomm_client/features/admin/admin_page.dart';
import 'package:ycomm_client/features/admin/admin_catalog_pages.dart';
import 'package:ycomm_client/features/admin/admin_system_pages.dart';
import 'package:ycomm_client/features/admin/admin_users_page.dart';
import 'package:ycomm_client/features/admin/moderation_page.dart';
import 'package:ycomm_client/features/api/api_explorer_page.dart';

import 'fixtures/admin_fixture.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/theme/theme_controller.dart';
import 'package:ycomm_client/main.dart';

import 'widget_test.dart' show TestApi;

void expectAppleTree() {
  for (final type in <Type>[
    Material,
    Scaffold,
    AppBar,
    InkWell,
    InkResponse,
    IconButton,
    FilledButton,
    TextButton,
    OutlinedButton,
    Card,
    ListTile,
    AlertDialog,
    Dialog,
    SnackBar,
    TextField,
    TextFormField,
    RefreshIndicator,
    CircularProgressIndicator,
    LinearProgressIndicator,
    ChoiceChip,
    FilterChip,
    Chip,
    Badge,
    SwitchListTile,
    CheckboxListTile,
    ExpansionTile,
    Tooltip,
    SelectableText,
  ]) {
    expect(
      find.byType(type, skipOffstage: false),
      findsNothing,
      reason: '$type leaked into Apple UI',
    );
  }
  expect(
    find.byWidgetPredicate(
      (w) => w is Icon && w.icon?.fontFamily == 'MaterialIcons',
      skipOffstage: false,
    ),
    findsNothing,
  );
}

void main() {
  testWidgets(
    'style changes preserve the current route and return navigation',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ThemeController.styleKey: 'material',
      });
      final container = ProviderContainer(
        overrides: [communityProvider.overrideWithValue(TestApi())],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const YCommApp(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppShell));
      Navigator.of(context)
          .push(appPageRoute(context, builder: (_) => const AppearancePage()));
      await tester.pumpAndSettle();
      await container
          .read(themeControllerProvider.notifier)
          .setStyle(DesignStyle.apple);
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePage), findsOneWidget);
      expectAppleTree();
      Navigator.of(tester.element(find.byType(AppearancePage))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(AppearancePage), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      expectAppleTree();
    },
  );

  testWidgets('Apple row supports keyboard activation without pointer motion', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      AppleApp(
        theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
        home: AppScaffold(
          body: PressableScale(onTap: () => taps++, child: const Text('打开条目')),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expectAppleTree();
  });

  testWidgets(
    'Apple notices replace each other without snackbar or lost text',
    (tester) async {
      await tester.pumpWidget(
        AppleApp(
          theme: buildAppleTheme(ThemeColour.azure, Brightness.dark),
          home: const AppScaffold(body: Text('页面')),
        ),
      );
      final context = tester.element(find.text('页面'));
      appNotice(context, '第一条提示');
      await tester.pump();
      appNotice(context, '第二条提示');
      await tester.pumpAndSettle();
      expect(find.text('第一条提示'), findsNothing);
      expect(find.text('第二条提示'), findsOneWidget);
      expectAppleTree();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('第二条提示'), findsNothing);
    },
  );

  testWidgets('desktop title bar hover uses Apple tooltip and glyphs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppleApp(
        theme: buildAppleTheme(ThemeColour.azure, Brightness.dark),
        builder: (context, child) => DesktopWindowFrame(child: child),
        home: const AppScaffold(body: Text('窗口内容')),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    final close = find.byWidgetPredicate(
      (w) => w is AppTooltip && w.message == '关闭',
    );
    await mouse.moveTo(tester.getCenter(close));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('关闭'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expectAppleTree();
    await mouse.removePointer();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'entire Apple shell and resource segments support enlarged text',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        ThemeController.styleKey: 'apple',
      });
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityProvider.overrideWithValue(TestApi())],
          child: AppleApp(
            theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'large text bottom tabs');
      await tester.tap(find.text('资源').last);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'large text resource segments',
      );
      expectAppleTree();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'Apple pages $brightness at 320px with large text have no Material UI',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          ThemeController.styleKey: 'apple',
        });
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final page in <Widget>[
          const AppearancePage(),
          const SettingsPage(),
          const AboutPage(),
          const LoginPage(),
          const RegisterPage(),
          const ForgotPasswordPage(),
          const ComposePage(
            boards: [
              {'id': 'b1', 'slug': 'board', 'name': '交流'},
            ],
          ),
          const SearchPage(),
          const TopicPage(id: 't1'),
          const MyPostsPage(),
          const ApiExplorerPage(),
          const AdminDashboardPage(),
          const ModerationPage(),
          const ModerationDetailPage(item: reviewItem),
          const AdminUsersPage(),
          const AdminUserDetailPage(user: managedUser),
          const AdminResourcesPage(),
          const AdminBoardsPage(),
          const AdminCardsPage(),
          const AdminBadgesPage(),
          const AdminInvitesPage(),
          const AdminAuditPage(),
          const AdminSettingsPage(),
          const AppScaffold(
            body: MarkdownContent('- [x] 完成\n- [ ] 未完成\n\n**可选择文本**'),
          ),
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                communityProvider.overrideWithValue(
                  page.runtimeType.toString().startsWith('Admin') ||
                          page is ModerationPage ||
                          page is ModerationDetailPage
                      ? AdminFixtureApi()
                      : TestApi(),
                ),
              ],
              child: AppleApp(
                theme: buildAppleTheme(ThemeColour.azure, brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.8),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$page initial layout',
          );
          expectAppleTree();
          final scroll = find.byWidgetPredicate(
            (w) => w is ListView || w is CustomScrollView,
          );
          if (scroll.evaluate().isNotEmpty) {
            await tester.drag(scroll.first, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$page scrolled layout',
            );
            expectAppleTree();
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );
  }
  testWidgets('Apple app tabs and login render without Material controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({ThemeController.styleKey: 'apple'});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(TestApi())],
        child: const YCommApp(),
      ),
    );
    await tester.pumpAndSettle();
    expectAppleTree();
    for (final label in ['资源', '消息', '我的']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expectAppleTree();
    }
    await tester.tap(find.text('登录 / 注册'));
    await tester.pumpAndSettle();
    expectAppleTree();
    expect(tester.takeException(), isNull);
  });
}
