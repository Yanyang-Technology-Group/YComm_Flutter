import 'package:ycomm_client/core/network/community_api.dart';

const markdownBoards = <Json>[
  {'id': 'b1', 'slug': 'news', 'name': '**官方公告**'},
  {'id': 'b2', 'slug': 'help', 'name': '*互助*与 `Flutter`'},
];

const markdownSample = '''
# 社区更新

欢迎阅读 **官方公告**。支持 *强调*、~~旧版本~~ 与 `行内代码`。

> 请在更新前备份本地资料。

## 更新内容

- [x] 版块与标题格式
- [ ] 后续版本安排

1. 下载更新
2. 重新启动

| 平台 | 版本 | 状态 |
| --- | --- | --- |
| Linux | 1.2.0 | **已发布** |
| Android | 1.2.0 | 测试中 |

```dart
final announcement = '**官方公告**';
print(announcement);
```

[社区资源](/downloads) · [参考说明][guide]

[guide]: https://example.com/guide
''';

class MarkdownApi extends CommunityApi {
  final calls = <String>[];
  Json? sentBody;
  Json topic = {
    'id': 't1',
    'title': '**九月更新**：社区体验优化',
    'board_id': 'b1',
    'author_id': 'owner',
    'authorUsername': 'xiaobai',
    'created_at': '2026-09-16T08:00:00Z',
    'view_count': 42,
    'reply_count': 3,
    'preview': {
      'firstPost': {
        'contentExcerpt':
            '本次更新包括 **版块格式**、*阅读体验* 和 `Markdown` 支持。\n\n[查看说明](/guide)',
      },
    },
  };
  @override
  Future<Json> get(String path, {Json? query}) async {
    calls.add(path);
    if (path == '/auth/me') {
      return {
        'user': {'id': 'owner', 'role': 'owner', 'state': 'active'},
      };
    }
    if (path == '/forum/boards' || path == '/admin/boards') {
      return {'boards': markdownBoards};
    }
    if (path == '/notifications') {
      return {
        'groups': [
          {
            'key': 'announcement',
            'title': '**公告通知**',
            'body': markdownSample,
            'unreadCount': 1,
          },
        ],
      };
    }
    if (path.contains('/boards/')) {
      return {
        'topics': [topic],
        'total': 1,
      };
    }
    if (path == '/forum/topics/t1') {
      return {
        'topic': topic,
        'posts': [
          {
            'id': 'p1',
            'authorUsername': 'xiaobai',
            'content_md': markdownSample,
          },
        ],
        'likedPostIds': [],
      };
    }
    return {};
  }

  @override
  Future<Json> post(String path, [Json? body]) async {
    sentBody = body;
    if (body?['action'] == 'move') {
      topic = {...topic, 'board_id': body!['boardId']};
    }
    return {'topic': topic};
  }
}
