/// API 浏览器的接口元数据。
///
/// 手工梳理自客户端实际调用点（`grep '\.get(|\.post(|\.patch(|\.delete(' lib/`），
/// 字段含义与 `ApiDocEndpoint` 的调用方约定一致。
library;

/// HTTP 方法。
enum ApiDocMethod { get, post, patch, delete }

/// 单个请求参数。
class ApiDocParam {
  const ApiDocParam({
    required this.name,
    required this.description,
    this.required = false,
    this.example = '',
  });

  final String name;
  final String description;
  final bool required;
  final String example;
}

/// 单个接口的文档。
class ApiDocEndpoint {
  const ApiDocEndpoint({
    required this.group,
    required this.route,
    required this.method,
    required this.summary,
    required this.description,
    this.params = const <ApiDocParam>[],
    this.runnableInExplorer = true,
  });

  final String group;
  final String route;
  final ApiDocMethod method;
  final String summary;
  final String description;
  final List<ApiDocParam> params;

  /// false 时仅展示文档，不提供「在线运行」按钮（例如需要浏览器跳转的 OAuth）。
  final bool runnableInExplorer;

  String get methodLabel => switch (method) {
    ApiDocMethod.get => 'GET',
    ApiDocMethod.post => 'POST',
    ApiDocMethod.patch => 'PATCH',
    ApiDocMethod.delete => 'DELETE',
  };
}

/// 全部接口清单。
///
/// 按调用点分组；`{param}` 形式的路由段会被 UI 当作路径参数，用户可直接改写。
const apiDocEndpoints = <ApiDocEndpoint>[
  // ── Auth ────────────────────────────────────────────────────────────────
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/me',
    method: ApiDocMethod.get,
    summary: '当前登录用户',
    description: '返回当前会话的用户信息；未登录时 data.user 为 null。',
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/login',
    method: ApiDocMethod.post,
    summary: '账号密码登录',
    description: '用用户名或邮箱加密码登录；服务端可能要求人机验证（captchaToken）。',
    params: [
      ApiDocParam(
        name: 'login',
        description: '用户名或邮箱',
        required: true,
        example: 'demo',
      ),
      ApiDocParam(
        name: 'password',
        description: '密码',
        required: true,
        example: 'password',
      ),
      ApiDocParam(name: 'rememberMe', description: '记住登录', example: 'true'),
      ApiDocParam(
        name: 'agreeTerms',
        description: '已同意服务协议与儿童保护规则',
        required: true,
        example: 'true',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/register',
    method: ApiDocMethod.post,
    summary: '注册账号',
    description: '创建新账号；可能要求人机验证与邀请码。',
    params: [
      ApiDocParam(
        name: 'username',
        description: '用户名',
        required: true,
        example: 'demo',
      ),
      ApiDocParam(
        name: 'email',
        description: '邮箱',
        required: true,
        example: 'demo@example.com',
      ),
      ApiDocParam(
        name: 'password',
        description: '密码',
        required: true,
        example: 'password',
      ),
      ApiDocParam(
        name: 'agreeTerms',
        description: '已同意服务协议与儿童保护规则',
        required: true,
        example: 'true',
      ),
      ApiDocParam(name: 'inviteCode', description: '邀请码（可选）', example: ''),
    ],
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/logout',
    method: ApiDocMethod.post,
    summary: '退出登录',
    description: '注销当前会话并清空本地 cookie。',
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/sessions',
    method: ApiDocMethod.get,
    summary: '登录设备列表',
    description:
        '当前账号的有效登录会话（一次登录 = 一条会话），当前会话排第一并标记 isCurrent。'
        '仅限 Session Cookie 调用，Bearer API 密钥返回 403。',
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/sessions/revoke-others',
    method: ApiDocMethod.post,
    summary: '退出其他所有设备',
    description:
        '一键撤销本账号除当前会话外的全部有效会话，返回 { revokedCount }。'
        '当前会话不受影响（退出当前会话用 /auth/logout）；重复调用返回 0。',
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/sessions/{sessionId}',
    method: ApiDocMethod.delete,
    summary: '退出指定设备',
    description:
        '撤销本账号的一条其他有效会话。目标是当前会话返回 409；不存在、已失效'
        '或不属于当前用户返回 404。仅限 Session Cookie 调用。',
    params: [
      ApiDocParam(
        name: 'sessionId',
        description: '会话 ID（登录设备列表里的 id）',
        required: true,
        example: '0b0f2a4e-8b1a-4c3d-9e2f-1234567890ab',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/forgot-password',
    method: ApiDocMethod.post,
    summary: '找回密码',
    description: '向邮箱发送重置邮件；可能要求人机验证。',
    params: [
      ApiDocParam(
        name: 'email',
        description: '注册邮箱',
        required: true,
        example: 'demo@example.com',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/me/topics',
    method: ApiDocMethod.get,
    summary: '我的讨论',
    description: '返回当前用户发起的讨论列表。',
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/me/resources',
    method: ApiDocMethod.get,
    summary: '我的资源',
    description: '返回当前用户上传的资源列表。',
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/me/posts',
    method: ApiDocMethod.get,
    summary: '我的回复',
    description: '返回当前用户发出的回复列表。',
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: '/auth/github',
    method: ApiDocMethod.get,
    summary: 'GitHub 登录跳转',
    description:
        '302 跳转到 GitHub 授权页，回调到 /auth/github/callback。仅供文档查看，无法在线运行。',
    runnableInExplorer: false,
  ),

  // ── Users ───────────────────────────────────────────────────────────────
  ApiDocEndpoint(
    group: 'Users',
    route: '/users/{username}',
    method: ApiDocMethod.get,
    summary: '用户主页',
    description: '返回指定用户的公开资料、关注关系与个人介绍。',
    params: [
      ApiDocParam(
        name: 'username',
        description: '用户名（路径参数）',
        required: true,
        example: 'demo',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Users',
    route: '/users/{username}/follow',
    method: ApiDocMethod.post,
    summary: '关注用户',
    description: '关注指定用户；需登录。',
    params: [
      ApiDocParam(
        name: 'username',
        description: '用户名（路径参数）',
        required: true,
        example: 'demo',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Users',
    route: '/users/{username}/unfollow',
    method: ApiDocMethod.post,
    summary: '取消关注',
    description: '取消对指定用户的关注；需登录。',
    params: [
      ApiDocParam(
        name: 'username',
        description: '用户名（路径参数）',
        required: true,
        example: 'demo',
      ),
    ],
  ),

  // ── Forum ───────────────────────────────────────────────────────────────
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/boards',
    method: ApiDocMethod.get,
    summary: '版块列表',
    description: '返回全部可见版块。',
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/boards/{slug}/topics',
    method: ApiDocMethod.get,
    summary: '版块话题列表',
    description: '返回指定版块下的讨论列表，分页。',
    params: [
      ApiDocParam(
        name: 'slug',
        description: '版块 slug（路径参数）',
        required: true,
        example: 'news',
      ),
      ApiDocParam(name: 'limit', description: '每页条数', example: '20'),
      ApiDocParam(name: 'offset', description: '偏移量', example: '0'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/boards/{slug}/topics',
    method: ApiDocMethod.post,
    summary: '发起讨论',
    description: '在指定版块下发新讨论；可能需审核。',
    params: [
      ApiDocParam(
        name: 'slug',
        description: '版块 slug（路径参数）',
        required: true,
        example: 'news',
      ),
      ApiDocParam(
        name: 'title',
        description: '标题',
        required: true,
        example: '第一条讨论',
      ),
      ApiDocParam(
        name: 'content',
        description: '正文（Markdown）',
        required: true,
        example: '内容……',
      ),
      ApiDocParam(
        name: 'replyToPostId',
        description: '引用的回复 ID（可选）',
        example: '',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/topics/{id}',
    method: ApiDocMethod.get,
    summary: '话题详情',
    description: '返回话题正文与回复列表；回复分页（offset）。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '话题 ID（路径参数）',
        required: true,
        example: '1',
      ),
      ApiDocParam(name: 'offset', description: '回复偏移量', example: '0'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/topics/{id}',
    method: ApiDocMethod.delete,
    summary: '删除话题',
    description: '删除指定话题及其回复；需作者本人或管理员。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '话题 ID（路径参数）',
        required: true,
        example: '1',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/topics/{id}/posts',
    method: ApiDocMethod.post,
    summary: '发表回复',
    description: '在话题下发表回复；可能需审核。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '话题 ID（路径参数）',
        required: true,
        example: '1',
      ),
      ApiDocParam(
        name: 'content',
        description: '回复内容（Markdown）',
        required: true,
        example: '同意',
      ),
      ApiDocParam(
        name: 'replyToPostId',
        description: '引用的回复 ID（可选）',
        example: '',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/topics/{id}/action',
    method: ApiDocMethod.post,
    summary: '话题操作',
    description: '锁定、置顶、移动等话题级操作；action 取值见前端调用点。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '话题 ID（路径参数）',
        required: true,
        example: '1',
      ),
      ApiDocParam(
        name: 'action',
        description: '操作类型',
        required: true,
        example: 'lock',
      ),
      ApiDocParam(name: 'boardId', description: '目标版块 ID（移动时）', example: ''),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/posts/{id}',
    method: ApiDocMethod.patch,
    summary: '编辑回复',
    description: '编辑指定回复的内容；需作者本人。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '回复 ID（路径参数）',
        required: true,
        example: '1',
      ),
      ApiDocParam(
        name: 'content',
        description: '新内容',
        required: true,
        example: '编辑后的内容',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/posts/{id}',
    method: ApiDocMethod.delete,
    summary: '删除回复',
    description: '删除指定回复；需作者本人或管理员。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '回复 ID（路径参数）',
        required: true,
        example: '1',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/posts/{id}/like',
    method: ApiDocMethod.post,
    summary: '点赞回复',
    description: '为指定回复点赞。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '回复 ID（路径参数）',
        required: true,
        example: '1',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/posts/{id}/unlike',
    method: ApiDocMethod.post,
    summary: '取消点赞',
    description: '取消对指定回复的点赞。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '回复 ID（路径参数）',
        required: true,
        example: '1',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Forum',
    route: '/forum/search',
    method: ApiDocMethod.get,
    summary: '搜索讨论',
    description: '按关键字搜索讨论；scope 目前固定 topics。',
    params: [
      ApiDocParam(
        name: 'q',
        description: '搜索关键字',
        required: true,
        example: 'flutter',
      ),
      ApiDocParam(name: 'scope', description: '搜索范围', example: 'topics'),
    ],
  ),

  // ── Downloads ───────────────────────────────────────────────────────────
  ApiDocEndpoint(
    group: 'Downloads',
    route: '/downloads/categories',
    method: ApiDocMethod.get,
    summary: '资源分类',
    description: '返回全部资源分类。',
  ),
  ApiDocEndpoint(
    group: 'Downloads',
    route: '/downloads/resources',
    method: ApiDocMethod.get,
    summary: '资源列表',
    description: '返回资源列表，可按分类筛选。',
    params: [
      ApiDocParam(name: 'categoryId', description: '分类 ID（可选）', example: ''),
    ],
  ),
  ApiDocEndpoint(
    group: 'Downloads',
    route: '/downloads/resources/{id}',
    method: ApiDocMethod.get,
    summary: '资源详情',
    description: '返回单个资源的详情。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '资源 ID（路径参数）',
        required: true,
        example: '1',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Downloads',
    route: '/downloads/resources/{id}/extract-code',
    method: ApiDocMethod.get,
    summary: '获取提取码',
    description: '返回资源的网盘提取码；需登录且未撤回。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '资源 ID（路径参数）',
        required: true,
        example: '1',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Downloads',
    route: '/downloads/resources/{id}/withdraw',
    method: ApiDocMethod.post,
    summary: '撤回资源',
    description: '撤回指定资源；需作者本人或管理员。',
    params: [
      ApiDocParam(
        name: 'id',
        description: '资源 ID（路径参数）',
        required: true,
        example: '1',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Downloads',
    route: '/downloads/cards',
    method: ApiDocMethod.get,
    summary: '卡片目录',
    description: '返回下载页的卡片式目录树。',
  ),

  // ── Notifications ───────────────────────────────────────────────────────
  ApiDocEndpoint(
    group: 'Notifications',
    route: '/notifications',
    method: ApiDocMethod.get,
    summary: '通知列表',
    description: '返回通知分组与未读数。',
  ),
  ApiDocEndpoint(
    group: 'Notifications',
    route: '/notifications/read',
    method: ApiDocMethod.post,
    summary: '标记已读',
    description: '把指定通知 key 标记为已读。',
    params: [
      ApiDocParam(
        name: 'keys',
        description: '通知 key 列表（逗号分隔）',
        required: true,
        example: 'n/1,n/2',
      ),
    ],
  ),
];
