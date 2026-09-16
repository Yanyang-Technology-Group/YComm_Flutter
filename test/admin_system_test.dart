import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/admin/admin_system_pages.dart';
import 'package:ycomm_client/features/admin/admin_widgets.dart';

class SystemApi extends CommunityApi {
  String role = 'owner';
  Json? patchData;
  Json resource = {
    'id': 'r',
    'authorId': 'other',
    'title': '资源一',
    'status': 'published',
    'sourceType': 'external',
  };
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/auth/me') {
      return {
        'user': {'id': 'a', 'role': role, 'state': 'active'},
      };
    }
    if (path == '/admin/settings') {
      return {
        'settings': [
          {'key': 'feature_flag', 'value': false},
        ],
      };
    }
    if (path == '/downloads/resources/r') return {'resource': resource};
    return {
      'resources': [resource],
      'total': 1,
    };
  }

  @override
  Future<Json> post(String path, [Json? data]) async {
    if (path == '/downloads/resources/r/withdraw') {
      resource = {...resource, 'status': 'withdrawn'};
      return {};
    }
    throw StateError('Unexpected mutation: $path');
  }

  @override
  Future<Json> patch(String path, Json data) async {
    patchData = data;
    return {};
  }
}

void main() {
  testWidgets(
    'withdrawal through public detail updates admin detail and list',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [communityProvider.overrideWithValue(SystemApi())],
          child: const MaterialApp(home: AdminResourcesPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('资源一'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看资源页面'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('撤回资源')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤回资源'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('撤回资源'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('已撤回'), findsOneWidget);
      expect(find.text('撤回资源'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AdminTile), matching: find.text('已撤回')),
        findsOneWidget,
      );
    },
  );
  testWidgets('boolean setting is submitted as a boolean not a JSON string', (
    tester,
  ) async {
    final api = SystemApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: const MaterialApp(home: AdminSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('feature_flag'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(api.patchData, {'key': 'feature_flag', 'value': true});
  });
  testWidgets('admin cannot withdraw another authors resource', (tester) async {
    final api = SystemApi()..role = 'admin';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: const MaterialApp(home: AdminResourcesPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('资源一'));
    await tester.pumpAndSettle();
    expect(find.text('撤回资源'), findsNothing);
  });
}
