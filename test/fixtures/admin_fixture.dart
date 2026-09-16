import 'package:ycomm_client/core/network/community_api.dart';

// Local UI fixtures only. No authenticated server is used by these tests.
const reviewItem = <String, dynamic>{
  'id': 'review-1',
  'target_type': 'post',
  'target_id': 'post-1',
  'status': 'pending',
  'reason': '新会员首次发布内容',
  'detail': {
    'content': '分享 Flutter 桌面端的开发经验，欢迎大家交流。',
    'topicTitle': '桌面应用开发交流',
  },
  'created_at': '2026-09-16T08:30:00Z',
};
const managedUser = <String, dynamic>{
  'id': 'user-1024',
  'username': 'chenxi',
  'displayName': '晨曦',
  'role': 'member',
  'state': 'active',
  'email': 'chenxi@example.com',
  'githubUsername': 'chenxi-dev',
  'inviteCodeUsed': 'AUTUMN',
  'createdAt': '2026-09-12T02:30:00Z',
  'lastLoginAt': '2026-09-16T08:00:00Z',
};

class AdminFixtureApi extends CommunityApi {
  @override
  Future<Json> get(String path, {Json? query}) async {
    if (path == '/auth/me') {
      return {
        'user': {'id': 'owner-1', 'role': 'owner', 'state': 'active'},
      };
    }
    if (path == '/admin/users') {
      return {
        'users': [managedUser],
        'total': 1,
      };
    }
    if (path == '/admin/moderation') {
      return {
        'items': [reviewItem],
      };
    }
    if (path == '/admin/boards') {
      return {
        'boards': [
          {
            'id': 'board-1',
            'slug': 'general',
            'name': '社区交流',
            'description': '日常讨论与经验分享',
            'sortOrder': 0,
            'visibility': 'public',
            'postingPolicy': 'all',
          },
        ],
      };
    }
    if (path == '/admin/cards') {
      return {
        'cards': [
          {
            'id': 'card-1',
            'title': '开发工具',
            'kind': 'container',
            'visibility': 'public',
            'status': 'published',
            'w': 1,
            'h': 1,
          },
          {
            'id': 'card-2',
            'parentId': 'card-1',
            'title': '社区资源',
            'kind': 'resources',
            'visibility': 'public',
            'status': 'pending',
            'w': 1,
            'h': 1,
          },
        ],
      };
    }
    if (path == '/admin/resources') {
      return {
        'resources': [
          {
            'id': 'resource-1',
            'authorId': 'user-1024',
            'categoryId': 'card-2',
            'title': '社区开发工具集',
            'versionLabel': '1.2.0',
            'sourceType': 'local',
            'status': 'published',
            'downloadCount': 128,
            'createdAt': '2026-09-16T08:00:00Z',
          },
        ],
        'total': 1,
      };
    }
    if (path == '/admin/audit') {
      return {
        'entries': [
          {
            'id': 'audit-1',
            'action': 'forum.topic.lock',
            'actorUsername': 'admin',
            'targetId': 'topic-1',
            'targetType': 'topic',
            'createdAt': '2026-09-16T08:30:00Z',
            'meta': {'reason': '讨论已结束'},
          },
        ],
        'total': 1,
      };
    }
    if (path == '/admin/settings') {
      return {
        'settings': [
          {'key': 'registration_enabled', 'value': true},
          {'key': 'site_name', 'value': '晏阳社区'},
          {
            'key': 'review_limits',
            'value': {'new_user_posts': 3},
          },
        ],
      };
    }
    if (path == '/admin/invites') {
      return {
        'inviteCodes': [
          {
            'id': 'invite-1',
            'name': '秋季社区邀请',
            'code': 'AUTUMN',
            'usedCount': 12,
            'maxUses': 100,
            'createdAt': '2026-09-12T08:00:00Z',
          },
        ],
      };
    }
    if (path == '/admin/badges') {
      return {
        'badges': [
          {
            'id': 'badge-1',
            'name': '社区贡献者',
            'colorFrom': '#5D94E8',
            'colorTo': '#62B35C',
          },
        ],
      };
    }
    if (path.endsWith('/badges')) return {'badges': []};
    throw StateError('Unexpected fixture path: $path');
  }
}
