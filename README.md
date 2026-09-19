# 晏阳社区 Flutter 客户端

面向手机竖屏的 Material 3 客户端。采用平铺列表与分隔线，删除装饰性卡片和标题说明文案；使用「社区 / 资源 / 消息 / 我的」导航；宽屏使用侧边导航。公开内容先浏览，发帖、回复、点赞、关注和下载时再登录，登录后返回原操作。

## 运行

```bash
flutter pub get
flutter run
```

服务端固定为 `https://community.yanyn.cn/api`。真实数据来自普通 API，应用不包含演示帖子或资源。测试中的 API 快照仅用于界面验证，不编入应用。

## 操作路径

- 社区：服务器版块 → 分页讨论流 → Markdown 正文与回复。支持主题搜索、发布讨论、回复、点赞、复制链接和作者主页。发布失败保留内容，退出编辑确认丢弃。
- 资源：多级目录逐层浏览，末级外链在浏览器打开；或切换社区分享 → 分类 → 资源详情 → 获取外链或下载文件。外链在系统浏览器打开；文件保存到应用文件夹，可调用系统应用打开。下载可取消，错误可重试。
- 消息：全部 / 未读、单组 / 全部标记已读；讨论、资源、用户主页通知在应用内打开，其他链接打开浏览器。
- 我的：会话状态、我的讨论、我的资源、个人主页、主题与关于。关于提供真实网站、服务协议、儿童个人信息保护规则和依赖许可入口。
- 认证：账号密码或 GitHub 登录、注册、找回密码；注册与重置邮件不泄露邮箱是否已存在。邮箱验证及密码重置按邮件链接完成。

## 外观

保留网站 Logo（仅去除透明外边距用于小尺寸显示）和五种颜色：晏阳蓝、猛男粉、纳西妲绿、活力橙、无强调色。支持跟随系统、浅色和深色，偏好保存在本机；未同步账号的网页端外观。Material 路由过渡、标签淡入和主题切换尊重系统减少动画设置。

## 会话与通知

启动时在应用私有支持目录初始化持久化 CookieJar；退出登录撤销服务端会话并清除 Cookie。WebSocket 使用同一 Session Cookie 和站点 Origin，不在 URL 中传递凭据。`ready` / `notification.changed` 触发 REST 刷新；断线指数退避，不可用时每 30 秒回退 REST。进入后台停止连接与轮询，回到前台重新确认会话。服务端会话失效后停止重连。

CAP 人机验证沿用本站官方组件，直接嵌入应用弹窗：登录、注册或找回密码需要验证时自动显示，用户手动点击验证，成功后自动关闭并继续原请求。不会启动系统浏览器。随机端口的本机回调只传递本次一次性 token，不接触账号密码或 Cookie；只允许验证页自身导航，CSP 限制页面仅访问本次本机会话。官方脚本、WASM 和 challenge/redeem 请求由应用通过 HTTPS 转发至固定白名单地址，避免系统 WebView 与应用网络配置差异；不转发登录 Cookie，不接受任意 URL 或重定向，不关闭证书校验。取消会清理验证会话；三分钟超时、加载失败可原地重新验证。支持浅色和深色。

内嵌组件使用 `webview_all`；项目最低版本为 Android 7.0（API 24）、iOS 15、macOS 12，Windows 需要 WebView2，Linux 需要 WebKitGTK 4.1。Android 仅为 `127.0.0.1` 放行本机 HTTP，其他流量仍要求 HTTPS；Apple 平台仅启用本地网络例外。Linux 构建和运行需安装 `webkit2gtk-4.1` 开发库。

## 验证

```bash
flutter analyze
flutter test
flutter build linux --debug
flutter build apk --debug
```

界面测试覆盖版块切换、详情、搜索、登录返回、主题持久化、草稿保护、分页失败重试，以及 320/390 宽度、1.8 倍文字和深色模式。网络测试覆盖 CAP 参数、Cookie 共享、错误信封、会话退出竞态、WebSocket 重连/失效/REST 回退。

可选截图验证（Linux 已安装 Noto CJK 字体）：

```bash
mkdir -p build/design-review
flutter test test/visual_review_test.dart --dart-define=VISUAL_REVIEW=true
```

截图输出到 `build/design-review`，使用 `test/fixtures/public_snapshot.json` 中的公开接口快照。字体仅在测试时加载，不依赖运行时在线字体。

真实账号的登录、注册邮件、发帖和下载仍需账号及人工验证码验证；自动化测试使用本地模拟服务，不会向生产社区发布测试内容。

原生验证码加载检查（不点击、不代做人机验证）：

```bash
flutter test integration_test/captcha_webview_test.dart -d linux
```

## GitHub 登录

登录和注册页均提供 GitHub 入口，先确认服务协议。授权在 GitHub 官方 HTTPS 页面完成；客户端不会读取 GitHub 密码、Cookie 或 access token。授权回到本站时，客户端核对精确回调地址与本次 state，再用隔离 CookieJar 请求现有后端，确认 `/auth/me` 后将社区会话保存至原生客户端，回到原操作。取消、授权拒绝、过期和网络失败可重新尝试。无需修改 GitHub 应用配置或部署新增服务端接口。外接浏览器仍没有原生会话交接能力。

自动化网络测试使用受控服务响应，覆盖成功会话、恶意回调、重复回调、失败和取消；真实账号、双重验证与移动真机需要人工验收。原生加载检查只打开官方表单，不填写或提交 GitHub 账号：

```bash
flutter test integration_test/github_webview_test.dart -d linux
```

Linux 的 WebView 使用系统代理配置。若授权页无法加载，请检查网络及代理协议；HTTP CONNECT 代理应使用 `http://` 代理地址，目标网站仍通过 HTTPS 连接。


## 发布与回复

社区底部输入框可直接输入正文，再补充标题与版块发布；讨论详情底部可直接输入并发送回复。点击楼层回复可指定对象，取消对象不会清空文字。发送失败保留草稿，离开未发送回复时确认丢弃。手机输入时显示系统键盘，桌面可直接键入。

应用名称为「晏阳社区」，各平台图标由原始晏阳 Logo 生成；重新生成可运行 `python3 tool/generate_icons.py`（需要 Pillow）。

## 版本号

版本号规则与 [YComm_WebSite](https://github.com/Yanyang-Technology-Group/YComm_WebSite) 一致：

```
v<yyyy.mm.dd>.<commits>      例如 v2026.09.19.9
```

`commits` 是发布时点仓库的提交总数（`git rev-list --count HEAD`）。发布工作流自动计算该值，并把同一个版本号写入各平台元数据：

| 平台 | 落点 | 值 |
| --- | --- | --- |
| 全部 | 「关于」页 | `yyyy.mm.dd.commits` |
| Android | `versionName` / `versionCode` | `yyyy.mm.dd.commits` / `yyyymmdd * 100 + commits % 100` |
| iOS、macOS | `CFBundleShortVersionString` / `CFBundleVersion` | `yyyy.mm.dd` / `commits` |
| Windows | `VERSIONINFO` FILEVERSION | `yyyy,mm,dd,commits` |
| Linux | `generated_config.cmake` | `yyyy.mm.dd+commits` |
| Web | `version.json` | `yyyy.mm.dd+commits` |

Apple 只接受 1–3 段整数，Windows `VERSIONINFO` 只接受四段 16 位整数，因此这两处无法直接写四段版本号；界面统一由 `--dart-define=YCOMM_VERSION` 拿到完整的 `yyyy.mm.dd.commits`。

`pubspec.yaml` 提交的是占位值 `0.0.0+0`。Web 的 `version.json`（Service Worker 判断是否需要更新）和桌面平台的 CMake/Xcode 配置都只读 `pubspec.yaml`，所以发布时先由 `tool/set_version.dart` 写入真实版本再构建。本地构建未注入版本时「关于」页显示「开发版」。

## 构建与发布

`ci.yml` 只在 PR 上做静态分析与测试。`release.yml` 在推送到 `main` 或手动运行（`workflow_dispatch`）时：先静态分析与测试，再解析版本号，然后并行构建六个平台，最后打 tag 并创建 GitHub Release。手动运行可用输入框强制指定版本号（如 `v2026.09.19.9`），留空则自动计算。

Release 附件：

| 平台 | 安装包 | 免安装包 |
| --- | --- | --- |
| Windows | `ycomm-windows-<版本>-setup.exe` | `ycomm-windows-<版本>.zip` |
| macOS | `ycomm-macos-<版本>.dmg` | `ycomm-macos-<版本>.zip` |
| Linux | `ycomm-linux-<版本>.deb` | `ycomm-linux-<版本>.tar.gz` |
| Android | — | `ycomm-android-<版本>.apk`（已签名）、`ycomm-android-<版本>.aab` |
| iOS | — | `ycomm-ios-<版本>-unsigned.xcarchive.zip` |
| Web | — | `ycomm-web-<版本>.tar.gz` |
| 校验 | `SHA256SUMS.txt` | |

包名：`cn.yanyn.community`。Linux 需要 `webkit2gtk-4.1`，Windows 需要系统 WebView2。macOS 的 `.dmg` 里带一个「应用程序」快捷方式，拖进去即可安装；Windows 安装包按用户安装（不需要管理员权限），因此安装过程不会弹 UAC。

## 发布者签名

三个桌面平台的产物都写入了发布者信息（Windows 版本资源、macOS `Info.plist`、`.deb` 的 control 文件）：

- 程序名：晏阳社区
- 发布者：晏阳技术组
- 版本：CI 注入的 `yyyy.mm.dd.commits`

**但这些元数据不会消除操作系统的安全提示。** Windows 的 UAC / SmartScreen 和 macOS 的 Gatekeeper 校验的是**代码签名证书**：没有证书时 Windows 一律显示「未知发布者」，macOS 一律提示「无法验证开发者」。只有配上证书才能真正去掉提示。

### 需要的证书

| 平台 | 证书 | 获取方式 | 费用 |
| --- | --- | --- | --- |
| Windows | 代码签名证书（OV/EV） | 向 CA（DigiCert、Sectigo、SSL.com 等）购买；2023 年后新签发的证书多为云签名或硬件令牌形式 | 约 200–500 美元/年；也可考虑 Azure Trusted Signing（约 10 美元/月，需企业资质） |
| macOS | Developer ID Application | 加入 Apple Developer Program 后在 Certificates 里创建并导出 `.p12` | 99 美元/年 |

证书 `Subject` 里的 `O=` 决定用户看到的发布者名字，申请时填「晏阳技术组」（或对应的法定主体名）。

### 配置方式

拿到证书后在仓库 Settings → Secrets and variables → Actions 添加对应项，工作流会自动开始签名。**没配置时不会失败**，只是跳过签名并打一条 warning，Release 说明里也会标注未签名。

Windows：

- `WINDOWS_CERT_PFX_BASE64` — `.pfx` 的 Base64：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.pfx"))`
- `WINDOWS_CERT_PASSWORD` — `.pfx` 密码

macOS：

- `APPLE_CERT_P12_BASE64` — Developer ID Application 证书 `.p12` 的 Base64
- `APPLE_CERT_PASSWORD` — `.p12` 密码
- `APPLE_SIGNING_IDENTITY` — 形如 `Developer ID Application: 晏阳技术组 (TEAMID)`
- `APPLE_ID` — Apple 账号邮箱
- `APPLE_TEAM_ID` — 团队 ID
- `APPLE_APP_PASSWORD` — App 专用密码

macOS 只配证书不配公证账号时，`.app` 会被签名但不会公证，Gatekeeper 仍可能提示；`codesign` → `notarytool` → `stapler` 三步都跑完才是完整链路。

### 未签名时用户怎么装

- **Windows**：安装包按用户安装，不需要管理员权限，安装过程**不弹 UAC**。从浏览器下载后首次运行会有 SmartScreen 提示，点「更多信息」→「仍要运行」。
- **macOS**：右键点图标选「打开」，或到「系统设置 → 隐私与安全性」点「仍要打开」。
- **Linux**：`.deb` 没有代码签名机制，不涉及。

Android Release 始终使用 GitHub Secrets 中保存的固定密钥，缺少任一项时构建失败，不回退到调试签名：

- `ANDROID_KEYSTORE_BASE64`、`ANDROID_STORE_PASSWORD`、`ANDROID_KEY_PASSWORD`、`ANDROID_KEY_ALIAS`

请备份原始密钥与密码，后续更新必须复用同一证书。

本地 Release 构建需创建被 Git 忽略的 `android/key.properties`：

```properties
storeFile=/absolute/path/to/release.jks
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=ycomm
```

## 许可证

本项目采用 [GNU Affero General Public License v3.0 或更高版本](LICENSE)（AGPL-3.0-or-later）。
