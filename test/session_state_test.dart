import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ycomm_client/core/network/community_api.dart';
import 'package:ycomm_client/core/state/session.dart';

class SessionApi extends CommunityApi {
  Completer<Json>? pending;
  @override
  Future<Json> get(String path, {Json? query}) async => pending == null
      ? {
          'user': {'id': 'one', 'username': 'tester'},
        }
      : await pending!.future;
  @override
  Future<Json> post(String path, [Json? data]) async => {};
}

void main() {
  test(
    'a stale session refresh cannot log a user back in after logout',
    () async {
      final api = SessionApi();
      final container = ProviderContainer(
        overrides: [communityProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.read(sessionProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sessionProvider).value?['id'], 'one');
      api.pending = Completer<Json>();
      final refresh = container.read(sessionProvider.notifier).refresh();
      await container.read(sessionProvider.notifier).logout();
      expect(container.read(sessionProvider).value, isNull);
      api.pending!.complete({
        'user': {'id': 'one'},
      });
      await refresh;
      expect(container.read(sessionProvider).value, isNull);
    },
  );
}
