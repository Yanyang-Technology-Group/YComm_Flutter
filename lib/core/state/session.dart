import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/community_api.dart';

class SessionController extends Notifier<AsyncValue<Json?>> {
  int _generation = 0;
  @override
  AsyncValue<Json?> build() {
    scheduleMicrotask(refresh);
    return const AsyncLoading();
  }

  Future<Json?> _load() async {
    try {
      final data = await ref.read(communityProvider).get('/auth/me');
      return data['user'] is Map ? Json.from(data['user']) : null;
    } on RequestFailure catch (e) {
      if ([
        'UNAUTHENTICATED',
        'UNAUTHORIZED',
        'AUTH_REQUIRED',
        '401',
      ].contains(e.code)) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    final ticket = ++_generation;
    final next = await AsyncValue.guard(_load);
    if (ref.mounted && ticket == _generation) state = next;
  }

  Future<void> logout() async {
    ++_generation;
    await ref.read(communityProvider).post('/auth/logout');
    ++_generation;
    await ref.read(communityProvider).client.clearSession();
    if (ref.mounted) state = const AsyncData(null);
  }
}

final sessionProvider = NotifierProvider<SessionController, AsyncValue<Json?>>(
  SessionController.new,
);
