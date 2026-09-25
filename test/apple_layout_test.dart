import 'package:ycomm_client/core/widgets/paged_feed.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycomm_client/core/design/adaptive.dart';
import 'package:ycomm_client/core/design/apple_chrome.dart';
import 'package:ycomm_client/core/design/apple_app.dart';
import 'package:ycomm_client/core/design/apple_theme.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/theme/app_theme.dart';
import 'package:ycomm_client/features/forum/forum_page.dart';
import 'package:ycomm_client/features/profile/profile_page.dart';
import 'package:ycomm_client/features/profile/user_page.dart';

import 'apple_native_test.dart' show expectAppleTree;
import 'widget_test.dart' show TestApi;

class LayoutApi extends TestApi {
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/layout/feed') {
      return {
        'topics': List.generate(30, (i) => {'id': '$i'}),
        'total': 30,
      };
    }
    if (path == '/users/member') {
      return {
        'profile': {'username': 'member', 'isSelf': true},
      };
    }
    return super.get(path, query: query);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(
    WidgetTester tester,
    Widget page,
    LayoutApi api, {
    double textScale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: AppleApp(
          theme: buildAppleTheme(ThemeColour.azure, Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: AppScaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Apple grouped feed keeps offscreen rows lazy', (tester) async {
    final built = <String>{};
    await mount(
      tester,
      PagedFeed(
        path: '/layout/feed',
        listKey: 'topics',
        emptyTitle: '',
        emptyMessage: '',
        itemBuilder: (row) => Builder(
          builder: (context) {
            built.add(row['id'] as String);
            return SizedBox(height: 180, child: Text('条目 ${row['id']}'));
          },
        ),
      ),
      LayoutApi(),
    );
    expect(built.length, lessThan(15));
    await tester.scrollUntilVisible(find.text('条目 29'), 500, maxScrolls: 20);
    await tester.pumpAndSettle();
    expect(find.text('条目 29'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expectAppleTree();
  });

  testWidgets('Apple grouped separators span the row after the icon inset', (
    tester,
  ) async {
    await mount(tester, const ProfilePage(), LayoutApi());
    final separators = find.byType(AppleSeparator);
    expect(separators, findsWidgets);
    for (final separator in separators.evaluate()) {
      final line = find.descendant(
        of: find.byElementPredicate((element) => identical(element, separator)),
        matching: find.byType(ColoredBox),
      );
      expect(tester.getSize(line).width, greaterThan(250));
    }
  });

  testWidgets('Apple account header is one navigation row, opens profile', (
    tester,
  ) async {
    await mount(
      tester,
      const ProfilePage(),
      LayoutApi()..signedIn = true,
      width: 320,
      textScale: 1.8,
    );
    expect(find.byType(AppFilledButton), findsNothing);
    final row = find.byKey(const ValueKey('apple-account-row'));
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(UserPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    expectAppleTree();
  });

  for (final width in [320.0, 900.0]) {
    testWidgets('Apple board picker changes feed and cancels at width $width', (
      tester,
    ) async {
      final api = LayoutApi();
      await mount(tester, const ForumPage(), api, width: width, textScale: 1.8);
      expect(find.byType(AppChoiceChip), findsNothing);
      final picker = find.byKey(const ValueKey('apple-board-picker'));
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(find.text('第二版块'), findsOneWidget);
      expectAppleTree();
      await tester.tap(find.text('第二版块'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('/forum/boards/second/topics'));
      expect(find.text('第二版块的内容'), findsOneWidget);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 650));
      await tester.pumpAndSettle();
      expect(find.text('第二版块的内容'), findsOneWidget);
      expect(find.byType(CupertinoMenuItem), findsNothing);
      expect(tester.takeException(), isNull);
      expectAppleTree();
    });
  }
}
