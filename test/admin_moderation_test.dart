import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/features/admin/moderation_page.dart';

class ModerationApi extends CommunityApi {
  bool fail = true;
  bool decided = false;
  Json? sent;
  String? sentPath;
  @override
  Future<Json> get(String path, {Json? query}) async => path == '/auth/me'
      ? {
          'user': {'id': 'a', 'role': 'admin', 'state': 'active'},
        }
      : {
          'items': [
            if (!decided)
              {
                'id': 'review1',
                'target_type': 'post',
                'target_id': 'post1',
                'status': 'pending',
                'reason': '新会员审核',
                'detail': {'content': '请审核这条回复'},
                'created_at': '2026-09-16T08:00:00Z',
              },
          ],
        };
  @override
  Future<Json> post(String path, [Json? data]) async {
    sent = data;
    sentPath = path;
    if (fail) throw const RequestFailure('暂时失败');
    decided = true;
    return {};
  }
}

void main() {
  testWidgets('approval closes both routes and refreshes the queue', (
    tester,
  ) async {
    final api = ModerationApi()..fail = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: const MaterialApp(home: ModerationPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新会员审核'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '已核对');
    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认通过'));
    await tester.pumpAndSettle();
    expect(api.sent, {'decision': 'approve', 'note': '已核对'});
    expect(find.text('暂时没有审核事项'), findsOneWidget);
    expect(find.text('审核详情'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('reject sends review item id and note; errors retain note', (
    tester,
  ) async {
    final api = ModerationApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: const MaterialApp(home: ModerationPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新会员审核'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '请补充来源');
    await tester.tap(find.text('驳回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认驳回'));
    await tester.pumpAndSettle();
    expect(api.sentPath, '/admin/moderation/review1/decide');
    expect(api.sent, {'decision': 'reject', 'note': '请补充来源'});
    expect(find.text('暂时失败'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('请补充来源'), findsOneWidget);
  });
}
