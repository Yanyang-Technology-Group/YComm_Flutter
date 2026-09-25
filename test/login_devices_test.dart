import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/api_client.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/profile/login_devices_page.dart';
import 'package:ycomm_client/features/profile/profile_page.dart';
import 'package:ycomm_client/features/profile/settings_page.dart';

/// 登录设备管理：三级入口、会话列表与退出操作的 Widget 测试。
class DevicesApi extends CommunityApi {
  DevicesApi({List<Json>? sessions}) : sessions = List.of(sessions ?? []);

  List<Json> sessions;
  bool loggedIn = true;
  bool failList = false;
  bool failRevoke = false;
  int listCalls = 0;
  final List<String> deleted = [];
  final List<String> posted = [];

  static final user = {
    'id': 'u1',
    'username': 'tester',
    'displayName': '测试用户',
    'role': 'member',
    'state': 'active',
    'level': 1,
  };

  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/auth/me') return {'user': loggedIn ? user : null};
    if (path == '/auth/sessions') {
      listCalls += 1;
      if (failList) throw const RequestFailure('网络错误');
      return {'sessions': sessions};
    }
    return {};
  }

  @override
  Future<Json> delete(String path) async {
    if (failRevoke) throw const RequestFailure('退出失败');
    deleted.add(path);
    final id = path.replaceFirst('/auth/sessions/', '');
    sessions = sessions.where((s) => s['id'] != id).toList();
    return {};
  }

  @override
  Future<Json> post(String path, [Json? data]) async {
    if (path == '/auth/logout') return {};
    if (path == '/auth/sessions/revoke-others') {
      if (failRevoke) throw const RequestFailure('退出失败');
      posted.add(path);
      final count = sessions.where((s) => s['isCurrent'] != true).length;
      sessions = sessions.where((s) => s['isCurrent'] == true).toList();
      return {'revokedCount': count};
    }
    return {};
  }
}

Json sessionView({
  required String id,
  required bool isCurrent,
  String device = 'YComm 客户端 · Android',
}) => {
  'id': id,
  'device': device,
  'ip': isCurrent ? null : '203.0.113.9',
  'createdAt': '2026-09-25T01:00:00.000Z',
  'lastUsedAt': isCurrent ? null : '2026-09-25T02:00:00.000Z',
  'expiresAt': '2026-10-01T01:00:00.000Z',
  'isCurrent': isCurrent,
};

Future<ProviderContainer> pumpPage(
  WidgetTester tester,
  DevicesApi api,
  Widget page,
) async {
  final container = ProviderContainer(
    overrides: [communityProvider.overrideWithValue(api)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('原生 User-Agent 固定格式 YCommFlutter/<平台>，不含个人信息', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final ua = nativeUserAgent();
    // 测试跑在原生 VM 上：kIsWeb 为 false，UA 必须存在且符合约定格式。
    expect(ua, matches(RegExp(r'^YCommFlutter/[A-Za-z]+$')));
    expect(ua, isNot(contains(' ')));
    expect(ua!.length, lessThan(40));
  });

  testWidgets('已登录时「我的 → 设置 → 账号安全 → 登录设备管理」可逐级进入', (
    tester,
  ) async {
    final api = DevicesApi(
      sessions: [
        sessionView(id: 's-cur', isCurrent: true),
        sessionView(id: 's-other', isCurrent: false, device: 'Chrome · Windows'),
      ],
    );
    await pumpPage(tester, api, const ProfilePage());

    await tester.ensureVisible(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('账号安全'), findsOneWidget);

    await tester.tap(find.text('账号安全'));
    await tester.pumpAndSettle();
    expect(find.text('登录设备管理'), findsOneWidget);

    await tester.tap(find.text('登录设备管理'));
    await tester.pumpAndSettle();
    expect(find.text('当前设备'), findsOneWidget);
    expect(find.text('YComm 客户端 · Android'), findsOneWidget);
    expect(find.text('Chrome · Windows'), findsOneWidget);
  });

  testWidgets('未登录时设置页不出现账号安全入口', (tester) async {
    final api = DevicesApi()..loggedIn = false;
    await pumpPage(tester, api, const SettingsPage());
    expect(find.text('账号安全'), findsNothing);
    expect(find.text('API 浏览器'), findsOneWidget);
  });

  testWidgets('列表区分当前与其他会话：当前设备只标记，不提供远程退出', (tester) async {
    final api = DevicesApi(
      sessions: [
        sessionView(id: 's-cur', isCurrent: true),
        sessionView(id: 's-other', isCurrent: false, device: 'Safari · iOS'),
      ],
    );
    await pumpPage(tester, api, const LoginDevicesPage());

    expect(find.text('当前设备'), findsOneWidget);
    expect(find.text('退出此设备'), findsOneWidget);
    expect(find.text('退出所有其他设备'), findsOneWidget);
    // 无记录的最近活跃时间
    expect(find.textContaining('暂无记录'), findsOneWidget);
  });

  testWidgets('取消确认不会发出任何退出请求', (tester) async {
    final api = DevicesApi(
      sessions: [
        sessionView(id: 's-cur', isCurrent: true),
        sessionView(id: 's-other', isCurrent: false),
      ],
    );
    await pumpPage(tester, api, const LoginDevicesPage());

    await tester.tap(find.text('退出此设备'));
    await tester.pumpAndSettle();
    expect(find.text('确认退出'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(api.deleted, isEmpty);
    expect(api.posted, isEmpty);
    // 列表原样保留
    expect(find.text('退出此设备'), findsOneWidget);
  });

  testWidgets('确认后单条退出只调用一次并刷新列表', (tester) async {
    final api = DevicesApi(
      sessions: [
        sessionView(id: 's-cur', isCurrent: true),
        sessionView(id: 's-other', isCurrent: false),
      ],
    );
    await pumpPage(tester, api, const LoginDevicesPage());
    final callsBefore = api.listCalls;

    await tester.tap(find.text('退出此设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认退出'));
    await tester.pumpAndSettle();

    expect(api.deleted, ['/auth/sessions/s-other']);
    expect(api.posted, isEmpty);
    expect(api.listCalls, greaterThan(callsBefore));
    expect(find.text('退出此设备'), findsNothing);
    expect(find.text('当前设备'), findsOneWidget);
  });

  testWidgets('一键退出其他设备只调用一次并刷新，保留当前会话', (tester) async {
    final api = DevicesApi(
      sessions: [
        sessionView(id: 's-cur', isCurrent: true),
        sessionView(id: 's-o1', isCurrent: false),
        sessionView(id: 's-o2', isCurrent: false, device: 'Firefox · Linux'),
      ],
    );
    await pumpPage(tester, api, const LoginDevicesPage());

    await tester.tap(find.text('退出所有其他设备'));
    await tester.pumpAndSettle();
    expect(find.text('确认全部退出'), findsOneWidget);

    await tester.tap(find.text('确认全部退出'));
    await tester.pumpAndSettle();

    expect(api.posted, ['/auth/sessions/revoke-others']);
    expect(api.deleted, isEmpty);
    expect(find.text('当前设备'), findsOneWidget);
    expect(find.text('退出此设备'), findsNothing);
    expect(find.text('退出所有其他设备'), findsNothing);
  });

  testWidgets('加载失败显示重试；重试成功后展示列表', (tester) async {
    final api = DevicesApi(sessions: [sessionView(id: 's-cur', isCurrent: true)])
      ..failList = true;
    await pumpPage(tester, api, const LoginDevicesPage());
    expect(find.text('重新加载'), findsOneWidget);

    api.failList = false;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(find.text('当前设备'), findsOneWidget);
    expect(find.text('重新加载'), findsNothing);
  });

  testWidgets('操作失败保留既有列表并展示错误', (tester) async {
    final api = DevicesApi(
      sessions: [
        sessionView(id: 's-cur', isCurrent: true),
        sessionView(id: 's-other', isCurrent: false),
      ],
    )..failRevoke = true;
    await pumpPage(tester, api, const LoginDevicesPage());

    await tester.tap(find.text('退出此设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认退出'));
    await tester.pumpAndSettle();

    expect(api.deleted, isEmpty);
    // 失败后旧列表仍在
    expect(find.text('退出此设备'), findsOneWidget);
    expect(find.text('当前设备'), findsOneWidget);
  });

  testWidgets('390 与 320 宽度下列表无溢出', (tester) async {
    for (final size in const [Size(390, 844), Size(320, 740)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = DevicesApi(
        sessions: [
          sessionView(id: 's-cur', isCurrent: true),
          sessionView(
            id: 's-other',
            isCurrent: false,
            device: 'YComm 客户端 · macOS',
          ),
        ],
      );
      await pumpPage(tester, api, const LoginDevicesPage());
      expect(find.text('当前设备'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
