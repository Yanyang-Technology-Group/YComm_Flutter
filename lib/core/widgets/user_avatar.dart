import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/community_api.dart';
import 'design.dart';

// Also serves notification/search rows whose APIs only include a username.
final avatarPathProvider = FutureProvider.autoDispose.family<String?, String>((
  ref,
  username,
) async {
  final data = await ref
      .read(communityProvider)
      .get('/users/${Uri.encodeComponent(username)}');
  final profile = data['profile'];
  return profile is Map ? profile['avatarPath'] as String? : null;
});

class UserAvatar extends ConsumerWidget {
  const UserAvatar(
    this.name, {
    super.key,
    this.size = 32,
    this.path,
    this.username,
  });
  final String name;
  final double size;
  final String? path, username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var resolved = path;
    if ((resolved == null || resolved.trim().isEmpty) &&
        username != null &&
        username!.isNotEmpty) {
      resolved = ref.watch(avatarPathProvider(username!)).asData?.value;
    }
    return PersonAvatar(name, size: size, url: resolved);
  }
}
