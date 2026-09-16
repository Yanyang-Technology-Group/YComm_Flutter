import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_client.dart';
import 'package:ycomm_client/core/network/api_result.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/state/session.dart';
import 'package:ycomm_client/features/admin/admin_users_page.dart';
import 'package:ycomm_client/features/auth/captcha_dialog.dart';

class UsersApi extends CommunityApi {
  UsersApi({super.client});
  final calls = <(String, Json?)>[];
  final posts = <(String, Json?)>[];
  final patches = <(String, Json)>[];
  bool failPost = false;
  Json sessionUser = {
    'id': 'owner',
    'username': 'root',
    'role': 'owner',
    'state': 'active',
  };
  @override
  Future<Json> get(String path, {Json? query}) async {
    calls.add((path, query));
    if (path == '/auth/me') {
      return {'user': sessionUser};
    }
    if (path == '/admin/users') {
      return {
        'users': [
          {
            'id': 'u 1',
            'username': 'alice',
            'displayName': '爱丽丝',
            'role': 'member',
            'state': 'active',
            'email': 'a@example.com',
          },
        ],
        'total': 1,
      };
    }
    if (path.endsWith('/badges')) return {'badges': []};
    if (path == '/admin/badges') return {'badges': []};
    return {};
  }

  @override
  Future<Json> post(String path, [Json? data]) async {
    posts.add((path, data));
    if (failPost) throw const RequestFailure('暂时无法提交');
    return {
      'user': {
        'id': 'u 1',
        'username': 'alice',
        'displayName': '爱丽丝',
        'role': 'member',
        'state': path.endsWith('/mute') ? 'muted' : 'active',
        'email': 'a@example.com',
        'muteReason': data?['reason'],
        'mutedUntil': data?['until'],
      },
      'badges': <Json>[],
    };
  }

  @override
  Future<Json> patch(String path, Json data) async {
    patches.add((path, data));
    return {
      'user': {
        'id': 'u 1',
        'username': 'alice',
        'displayName': '爱丽丝',
        'role': data['role'],
        'state': 'active',
        'email': 'a@example.com',
      },
    };
  }
}

class BadgeApi extends UsersApi {
  final pending = Completer<Json>();
  int requests = 0;
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/admin/badges') {
      return {
        'badges': [
          {'id': 'badge1', 'name': '贡献者'},
        ],
      };
    }
    return super.get(path, query: query);
  }

  @override
  Future<Json> post(String path, [Json? data]) async {
    if (path.endsWith('/badges/badge1')) {
      requests++;
      return pending.future;
    }
    return super.post(path, data);
  }
}

class CaptchaRequiredClient extends ApiClient {
  int postCount = 0;
  Json? firstBody;
  @override
  Future<ApiResult<dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    postCount++;
    firstBody = data;
    return ApiResult.fromJson({
      'ok': false,
      'error': {
        'code': 'VALIDATION_FAILED',
        'meta': {
          'issues': [
            {'path': 'captchaToken', 'message': '请完成人机验证'},
          ],
        },
      },
    });
  }
}

Future<UsersApi> openDetail(
  WidgetTester tester, {
  UsersApi? api,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final value = api ?? UsersApi();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [communityProvider.overrideWithValue(value)],
      child: MaterialApp(
        key: UniqueKey(),
        themeMode: themeMode,
        darkTheme: ThemeData.dark(),
        home: const AdminUsersPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('爱丽丝'));
  await tester.pumpAndSettle();
  return value;
}

Future<void> reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    260,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await Scrollable.ensureVisible(
    tester.element(find.text(text)),
    alignment: .5,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'returning from user details after account change does not refresh disposed list',
    (tester) async {
      final api = await openDetail(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AdminUserDetailPage)),
      );
      api.sessionUser = {
        'id': 'other-owner',
        'role': 'owner',
        'state': 'active',
      };
      await container.read(sessionProvider.notifier).refresh();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('爱丽丝'), findsNothing);
    },
  );
  testWidgets('badge assignment disables duplicate requests until completed', (
    tester,
  ) async {
    final api = BadgeApi();
    await openDetail(tester, api: api);
    await reveal(tester, '贡献者');
    await tester.tap(find.text('贡献者'));
    await tester.pump();
    await tester.tap(find.text('贡献者'));
    await tester.pump();
    expect(api.requests, 1);
    api.pending.complete({
      'badges': [
        {'id': 'badge1', 'name': '贡献者'},
      ],
    });
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
  });

  testWidgets('password CAPTCHA cannot retry after changing owner accounts', (
    tester,
  ) async {
    final client = CaptchaRequiredClient();
    final api = UsersApi(client: client);
    await openDetail(tester, api: api);
    await reveal(tester, '重置密码');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminUserDetailPage)),
    );
    await tester.tap(find.text('重置密码'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '新密码'),
      ' 12345678 ',
    );
    await tester.tap(find.text('继续确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置密码').last);
    await tester.pump();
    expect(find.byType(CaptchaDialog), findsOneWidget);
    api.sessionUser = {'id': 'other-owner', 'role': 'owner', 'state': 'active'};
    await container.read(sessionProvider.notifier).refresh();
    await tester.pump();
    Navigator.of(tester.element(find.byType(CaptchaDialog)))
        .pop('completed-token');
    await tester.pumpAndSettle();
    expect(client.postCount, 1);
    expect(client.firstBody, {'newPassword': ' 12345678 '});
  });
  test('punishment request always states finite UTC or permanent null', () {
    final local = DateTime(2026, 9, 18, 9, 30);
    expect(adminPunishmentPayload('  spam  ', local), {
      'reason': 'spam',
      'until': local.toUtc().toIso8601String(),
    });
    expect(adminPunishmentPayload('', null), {'until': null});
  });

  test('owner controls are limited to a usable owner session', () {
    expect(
      canManageUserOwnerActions({
        'id': 'x',
        'role': 'owner',
        'state': 'active',
      }),
      isTrue,
    );
    expect(
      canManageUserOwnerActions({
        'id': 'x',
        'role': 'admin',
        'state': 'active',
      }),
      isFalse,
    );
    expect(
      canManageUserOwnerActions({
        'id': 'x',
        'role': 'owner',
        'state': 'banned',
      }),
      isFalse,
    );
  });

  testWidgets('search uses q contract and opens identity detail', (
    tester,
  ) async {
    final api = UsersApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: const MaterialApp(home: AdminUsersPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('爱丽丝'), findsOneWidget);
    expect(find.textContaining('a@example.com'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'alice bob');
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    expect(
      api.calls.any(
        (c) =>
            c.$1 == '/admin/users' &&
            c.$2?['q'] == 'alice bob' &&
            c.$2?['limit'] == 30,
      ),
      isTrue,
    );
    await tester.tap(find.text('爱丽丝'));
    await tester.pumpAndSettle();
    expect(find.text('账号信息'), findsOneWidget);
    expect(find.text('a@example.com'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('修改角色'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('修改角色'), findsOneWidget);
  });

  testWidgets('mute submits a finite default and permanent submits null', (
    tester,
  ) async {
    final api = await openDetail(tester);
    await reveal(tester, '禁言');
    final before = DateTime.now().toUtc();
    await tester.tap(find.text('禁言'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '原因（可选）'), '刷屏');
    await tester.tap(find.text('确认禁言'));
    await tester.pumpAndSettle();
    final finite = api.posts.single.$2!;
    final until = DateTime.parse(finite['until'] as String);
    expect(finite['reason'], '刷屏');
    expect(until.isUtc, isTrue);
    expect(
      until.difference(before).inMilliseconds,
      inInclusiveRange(
        const Duration(hours: 23, minutes: 59).inMilliseconds,
        const Duration(hours: 24, minutes: 1).inMilliseconds,
      ),
    );

    // Use a fresh active user because the successful first request changes the detail state.
    final second = await openDetail(tester);
    await reveal(tester, '禁言');
    await tester.tap(find.text('禁言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24 小时'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认禁言'));
    await tester.pumpAndSettle();
    expect(second.posts.single.$2, {'until': null});
  });

  testWidgets('failed punishment keeps entered reason for retry', (
    tester,
  ) async {
    final api = UsersApi()..failPost = true;
    await openDetail(tester, api: api);
    await reveal(tester, '禁言');
    await tester.tap(find.text('禁言'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '原因（可选）'),
      '需要保留的原因',
    );
    await tester.tap(find.text('确认禁言'));
    await tester.pumpAndSettle();
    expect(find.text('暂时无法提交'), findsOneWidget);
    expect(find.text('需要保留的原因'), findsOneWidget);
    expect(find.text('确认禁言'), findsOneWidget);
  });

  testWidgets('owner role change sends the selected role', (tester) async {
    final api = await openDetail(tester);
    await reveal(tester, '修改角色');
    await tester.tap(find.text('修改角色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('会员').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理员').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('修改角色').last);
    await tester.pumpAndSettle();
    expect(api.patches, hasLength(1));
    expect(api.patches.single.$1, '/admin/users/u%201/role');
    expect(api.patches.single.$2, containsPair('role', 'admin'));
  });

  testWidgets('cancelled password CAPTCHA sends no final retry', (
    tester,
  ) async {
    final client = CaptchaRequiredClient();
    await openDetail(tester, api: UsersApi(client: client));
    await reveal(tester, '重置密码');
    await tester.tap(find.text('重置密码'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '新密码'),
      '12345678',
    );
    await tester.tap(find.text('继续确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置密码').last);
    await tester.pump();
    expect(find.text('完成人机验证'), findsOneWidget);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(client.postCount, 1);
    expect(client.firstBody, {'newPassword': '12345678'});
    expect(find.text('尚未完成人机验证，请重试'), findsOneWidget);
  });

  testWidgets('detail and punishment fit 320px dark layout at 1.8x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = UsersApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const AdminUsersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('爱丽丝'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await reveal(tester, '禁言');
    await tester.tap(find.text('禁言'));
    await tester.pumpAndSettle();
    expect(find.text('24 小时'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
