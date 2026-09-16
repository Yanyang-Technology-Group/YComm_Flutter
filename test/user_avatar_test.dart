import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/widgets/design.dart';
import 'package:ycomm_client/core/widgets/user_avatar.dart';

class AvatarApi extends CommunityApi {
  final calls = <String>[];
  @override
  Future<Json> get(String path, {Json? query}) async {
    calls.add(path);
    return {
      'profile': {'avatarPath': '/uploads/member.png'},
    };
  }
}

void main() {
  testWidgets('relative and external avatar URLs resolve correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            PersonAvatar('甲', url: '/uploads/a.png'),
            PersonAvatar(
              '乙',
              url: 'https://avatars.githubusercontent.com/u/123',
            ),
            PersonAvatar('丙', url: ''),
            PersonAvatar('丁', url: 'file:///tmp/private.png'),
          ],
        ),
      ),
    );
    final urls = tester
        .widgetList<Image>(find.byType(Image))
        .map((i) => (i.image as NetworkImage).url)
        .toList();
    expect(urls, [
      'https://community.yanyn.cn/uploads/a.png',
      'https://avatars.githubusercontent.com/u/123',
    ]);
    await tester.pumpAndSettle();
    // Test HTTP images fail: failed/missing images retain the user's initial.
    for (final name in ['甲', '乙', '丙', '丁']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('username-only avatars share one profile lookup', (tester) async {
    final api = AvatarApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [communityProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Row(
            children: [
              UserAvatar('甲', username: 'member'),
              UserAvatar('甲', username: 'member'),
              UserAvatar('乙', username: 'other', path: '/uploads/other.png'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.calls, ['/users/member']);
    expect(
      tester
          .widgetList<PersonAvatar>(find.byType(PersonAvatar))
          .map((a) => a.url),
      ['/uploads/member.png', '/uploads/member.png', '/uploads/other.png'],
    );
    expect(tester.takeException(), isNull);
  });
}
