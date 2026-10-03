// 桌面端外壳：自绘标题栏所需的窗口设置、系统托盘、右下角系统通知。
//
// 自绘标题栏的前提（已核对 window_manager 的 Windows 实现）：它的
// setTitleBarStyle(hidden) 只是 DwmExtendFrameIntoClientArea(0,0,0,0) 加
// SWP_FRAMECHANGED，**不动 WS_THICKFRAME**，所以隐藏系统标题栏之后窗口边缘
// 仍然可以拉伸缩放；拖动、最小化、最大化、关闭改由 Flutter 侧调用
// startDragging / minimize / maximize / close。
import 'dart:io'
    show Directory, File, Platform, Process, ProcessStartMode, exit;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart'
    show VoidCallback, debugPrint, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart' show MaterialApp, Rect, Widget;
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:nativeapi/nativeapi.dart' show LaunchAtLogin;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'gpu_probe_ffi.dart';
import '../../features/media/video_player_page.dart';

/// 是否是支持托盘与自绘标题栏的桌面平台。
bool get isDesktopShell =>
    !kIsWeb &&
    // widget test 也跑在桌面系统上（CI 的 Linux、开发机的 Windows），但那时既没有
    // 原生端，多出来的自绘标题栏还会把布局用例顶掉，所以测试环境一律当作非桌面。
    !Platform.environment.containsKey('FLUTTER_TEST') &&
    (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// 自绘标题栏的高度，也是可拖动区域的高度。
const double desktopTitleBarHeight = 38;

TrayIcon? _trayIcon;
Menu? _trayMenu;
bool _readyToShow = false;
/// 正在创建托盘（enableTray 里有 await，重入会建出第二个图标）。
bool _trayCreating = false;
/// 窗口当前是否收在托盘里（用来判断延迟补摘任务栏按钮还要不要做）。
bool _windowHidden = false;

Future<void> _ensureReadyToShow() async {
  if (_readyToShow || !isDesktopShell) return;
  // 失败必须向上传递，不能继续调用原生 setSkipTaskbar（taskbar_ 仍为空）。
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow();
  _readyToShow = true;
}

/// 启动时调用一次：初始化窗口与通知。
Future<void> setupDesktopShell() async {
  if (!isDesktopShell) {
    return;
  }
  try {
    await windowManager.ensureInitialized();
    await _ensureReadyToShow();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    // 自绘之后如果没有最小尺寸，窗口可以被拖到几乎没有，页面上就没法操作了。
    await windowManager.setMinimumSize(const Size(720, 520));
    await localNotifier.setup(appName: '晏阳社区');
  } catch (error) {
    debugPrint('初始化桌面外壳失败：$error');
  }
}

// ---- 窗口操作（自绘标题栏的按钮用）----

Future<void> startWindowDrag() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.startDragging();
}

Future<void> minimizeWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.minimize();
}

/// 最大化 / 还原。
Future<void> toggleMaximizeWindow() async {
  if (!isDesktopShell) {
    return;
  }
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

Future<bool> isWindowMaximized() async =>
    isDesktopShell && await windowManager.isMaximized();

/// 真正退出（不经过「最小化到托盘」）。
Future<void> destroyWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.destroy();
}

/// 请求关闭窗口。托盘开启时会被 onWindowClose 拦成「隐藏到托盘」。
Future<void> closeWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.close();
}

/// 隐藏窗口（最小化到托盘）。
///
/// 顺序很关键：window_manager 的 Windows 实现里 SetSkipTaskbar 会先
/// ShowWindow(SW_HIDE)、改扩展样式（WS_EX_TOOLWINDOW / WS_EX_APPWINDOW），
/// 再按**调用前**的可见性把窗口恢复显示。先摘任务栏再隐藏时，这次「恢复显示」
/// 会把任务栏按钮重新带出来，用户看到的就是「收进托盘了，任务栏按钮还在」。
/// 所以先隐藏：此时可见性已经是 false，改完样式的恢复动作仍是 SW_HIDE。
Future<void> hideWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await _ensureReadyToShow();
  await windowManager.hide();
  _windowHidden = true;
  await windowManager.setSkipTaskbar(true);
  // 有些 shell 要等隐藏动画/重排结束才刷新任务栏，稍后再补一次；
  // 这期间用户若已经把窗口叫回来（_windowHidden=false），这次就不动手。
  Future<void>.delayed(const Duration(milliseconds: 150), () async {
    if (!_windowHidden || !isDesktopShell) {
      return;
    }
    try {
      await windowManager.setSkipTaskbar(true);
    } catch (error) {
      debugPrint('再次摘掉任务栏按钮失败：$error');
    }
  });
}

Future<void> showMainWindow() async {
  if (!isDesktopShell) {
    return;
  }
  await _ensureReadyToShow();
  _windowHidden = false;
  await windowManager.setSkipTaskbar(false);
  await windowManager.show();
  await windowManager.focus();
}

/// 让关闭按钮由 Flutter 处理（托盘开启时改成隐藏窗口）。
Future<void> preventWindowClose(bool prevent) async {
  if (!isDesktopShell) {
    return;
  }
  await windowManager.setPreventClose(prevent);
}

/// 窗口整体透明度（1.0 = 完全不透明，0.1 = 最淡）。桌面三平台都支持。
Future<void> setWindowOpacity(double value) async {
  if (!isDesktopShell) {
    return;
  }
  await _ensureReadyToShow();
  await windowManager.setOpacity(value.clamp(0.1, 1.0));
}

/// 切换窗口 / 任务栏 / 启动器图标。
///
/// Windows：只切窗口与任务栏图标（exe 内嵌图标是构建期资源）。window_manager
///   要的是**磁盘路径**，而 Flutter 资源在打包后位于 exe 同级的
///   `data/flutter_assets/` 下；直接传 "assets/app_icon.ico" 这种资源键会失败，
///   整条设置链也跟着断掉。
/// 其他平台：交给各自 runner 的 cn.yanyn.community/app_icon 通道（Windows runner
///   没有实现这个通道，所以这里不能对它调用，否则会抛 MissingPluginException）。
Future<void> setDesktopWindowIcon(String iconAsset) async {
  if (!isDesktopShell) {
    return;
  }
  if (Platform.isWindows) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final icon = iconAsset.replaceFirst(RegExp(r'\.png$'), '.ico');
    final onDisk = File('$exeDir\\data\\flutter_assets\\$icon');
    if (!onDisk.existsSync()) {
      debugPrint('找不到窗口图标文件：${onDisk.path}');
      return;
    }
    await windowManager.setIcon(onDisk.path);
    return;
  }
  await const MethodChannel('cn.yanyn.community/app_icon').invokeMethod<void>(
    'setIcon',
    {'style': iconAsset.contains('classic') ? 'classic' : 'new'},
  );
}

// ---- 系统托盘 ----

// ---- GPU 加速 ----

/// 渲染模式是启动参数，进程跑起来就改不了，所以用一个环境变量记住
/// 「这个进程是按哪种模式起来的」。
const _gpuModeEnvKey = 'YCOMM_GPU_MODE';
/// 引擎启动时读的开关环境变量（shell/common/switches.cc 的 env 通道）。
const _softwareRenderingSwitch = 'FLUTTER_ENGINE_SWITCH_1';
/// 与 DesktopSettingsController.gpuKey 保持一致（启动早期只读一次 prefs）。
const _gpuPrefsKey = 'ycomm_desktop_gpu';

bool? _gpuSupportedCache;

/// 这台机器/驱动是否真的支持硬件加速。
///
/// macOS：Metal 在受支持的 macOS 上恒定可用。
/// Linux：有 DRI 设备（/dev/dri）才谈得上硬件渲染，纯软件环境没有这个目录。
/// Windows：问 D3D11 要一个硬件设备。
bool gpuAccelerationSupported() {
  if (!isDesktopShell) {
    return false;
  }
  final cached = _gpuSupportedCache;
  if (cached != null) {
    return cached;
  }
  var supported = false;
  try {
    if (Platform.isMacOS) {
      supported = true;
    } else if (Platform.isLinux) {
      supported = Directory('/dev/dri').existsSync();
    } else if (Platform.isWindows) {
      supported = windowsHasHardwareGpu();
    }
  } catch (error) {
    debugPrint('探测 GPU 加速能力失败：$error');
    supported = false;
  }
  _gpuSupportedCache = supported;
  return supported;
}

/// 当前进程是不是按「软件渲染」起来的。
bool get runningWithoutGpuAcceleration =>
    isDesktopShell && Platform.environment[_gpuModeEnvKey] == 'software';

/// 带上新的渲染开关重启客户端；返回是否成功拉起新进程。
///
/// 关掉 GPU 加速时把引擎开关塞进环境变量，子进程启动时引擎就会按软件渲染初始化。
Future<bool> relaunchWithGpuAcceleration(bool gpu) async {
  if (!isDesktopShell) {
    return false;
  }
  try {
    final environment = Map<String, String>.from(Platform.environment);
    environment[_gpuModeEnvKey] = gpu ? 'gpu' : 'software';
    if (gpu) {
      environment.remove(_softwareRenderingSwitch);
    } else {
      environment[_softwareRenderingSwitch] = 'enable-software-rendering';
    }
    await Process.start(
      _launchAtLoginExecutable(),
      const <String>[],
      environment: environment,
      mode: ProcessStartMode.detached,
    );
    return true;
  } catch (error) {
    debugPrint('按新的渲染模式重启失败：$error');
    return false;
  }
}

/// 启动时对齐渲染模式：上次关掉了 GPU 加速、这次却不是带着开关起来的，
/// 就自己带开关重启一次（只做一次：子进程带着标记，不会再触发）。
///
/// 只在正式包里做，避免打断 flutter run / 调试会话。
Future<void> alignGpuAccelerationOnLaunch() async {
  if (!isDesktopShell || !kReleaseMode || !gpuAccelerationSupported()) {
    return;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_gpuPrefsKey) ?? true) {
      return;
    }
    if (runningWithoutGpuAcceleration) {
      return;
    }
    if (await relaunchWithGpuAcceleration(false)) {
      exit(0);
    }
  } catch (error) {
    debugPrint('对齐 GPU 加速设置失败：$error');
  }
}

/// 打开托盘。
Future<void> enableTray({
  required VoidCallback onShowWindow,
  required VoidCallback onCheckUpdate,
  required VoidCallback onExit,
  String iconAsset = 'assets/app_icon.png',
}) async {
  if (!isDesktopShell) {
    return;
  }
  // 并发重入保护：applyDesktopSettings 可能连着触发两次（fireImmediately + load 完成），
  // 中间隔着 await，第二次进来时 _trayIcon 还没赋值，就会在任务栏旁边的托盘区多出一个图标。
  if (_trayCreating) {
    return;
  }
  if (_trayIcon != null) {
    _trayIcon!.icon = ImageAsset.fromAsset(iconAsset);
    return;
  }
  _trayCreating = true;
  try {
    final tray = TrayIcon.create();
    if (tray == null) {
      return;
    }
    tray.icon = ImageAsset.fromAsset(iconAsset);
    tray.setTooltip('晏阳社区');

    final menu = Menu.create();
    if (menu == null) {
      return;
    }
    void addItem(String label, VoidCallback action, {bool first = false}) {
      if (!first) {
        menu.addSeparator();
      }
      final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
      item?.addListener((event) {
        if (event is MenuItemClickedEvent) {
          action();
        }
      });
      menu.addItem(item);
    }

    // 分隔线只加在项之间，第一项前面不加。
    final show = MenuItem.createWithLabelAndType('显示主窗口', MenuItemType.normal);
    show?.addListener((event) {
      if (event is MenuItemClickedEvent) {
        onShowWindow();
      }
    });
    menu.addItem(show);
    addItem('检查更新', onCheckUpdate);
    addItem('退出', onExit);

    tray.setContextMenu(menu);
    // 只调 setContextMenu 是不会弹菜单的：nativeapi 的默认 trigger 是 none，
    // 必须显式告诉它「什么时候弹」。Windows/macOS 由原生在右键时弹；Linux 的
    // 托盘菜单是桌面面板画的，面板只在 trigger=clicked 时才通过 DBusMenu 把菜单
    // 暴露出来（Linux 上图标点击也不会回调到 Dart，OpenContextMenu() 是空实现）。
    tray.setContextMenuTrigger(
      Platform.isLinux
          ? ContextMenuTrigger.clicked
          : ContextMenuTrigger.rightClicked,
    );
    // 左键单击托盘图标也回到窗口：Windows 上单击上报 down/up。
    tray.addListener((event) {
      if (event is TrayIconClickedEvent ||
          event is TrayIconDoubleClickedEvent) {
        onShowWindow();
      }
    });
    tray.setVisible(true);

    _trayIcon = tray;
    _trayMenu = menu;
  } catch (error) {
    debugPrint('启用系统托盘失败：$error');
  } finally {
    _trayCreating = false;
  }
}

/// 关掉托盘。
Future<void> disableTray() async {
  try {
    _trayIcon?.setVisible(false);
    _trayIcon?.dispose();
  } catch (error) {
    debugPrint('关闭系统托盘失败：$error');
  }
  _trayIcon = null;
  _trayMenu?.dispose();
  _trayMenu = null;
}

// ---- 开机自启动 ----

/// 自启动注册项标识：Windows 是 HKCU\...\Run 下的值名，Linux 是
/// `~/.config/autostart/<id>.desktop` 的文件名，macOS 是 LaunchAgent 的 label。
/// 带命名空间是为了不跟别的程序撞名字，也方便以后改名/迁移时清理旧项。
const launchAtLoginId = 'com.yanyang.ycomm.client';

/// 系统「启动应用」列表里显示的名字（macOS/Linux 会用它）。
const launchAtLoginName = '晏阳社区';

/// 打包成 AppImage 时真实入口是 $APPIMAGE；resolvedExecutable 指向解压出来的
/// 临时目录（每次启动路径都不同），写进自启动项会直接失效。
String _launchAtLoginExecutable() {
  final appImage = Platform.environment['APPIMAGE'];
  if (appImage != null && appImage.isNotEmpty) {
    return appImage;
  }
  return Platform.resolvedExecutable;
}

/// 建一个自启动句柄。每次读写都新建、用完 dispose：状态存在系统里
/// （注册表 / .desktop 文件 / plist），原生对象本身不持有状态。
LaunchAtLogin? _createLauncher() {
  if (!isDesktopShell) {
    return null;
  }
  try {
    if (!LaunchAtLogin.isSupported()) {
      return null;
    }
    final launcher = LaunchAtLogin.createWithIdAndDisplayName(
      launchAtLoginId,
      launchAtLoginName,
    );
    // 显式指定可执行文件：默认探测在打包/AppImage 情况下不一定准。
    launcher?.setProgram(_launchAtLoginExecutable(), const <String>[]);
    return launcher;
  } catch (error) {
    debugPrint('创建开机自启动句柄失败：$error');
    return null;
  }
}

/// 当前平台是否支持开机自启动（桌面三平台都支持，Web/手机端没有这个概念）。
bool isLaunchAtLoginSupported() => _createLauncher() != null;

/// 系统里真实的自启动状态。读的是系统注册项，不是本地缓存。
Future<bool> isLaunchAtLoginEnabled() async {
  final launcher = _createLauncher();
  if (launcher == null) {
    return false;
  }
  try {
    return launcher.isEnabled;
  } catch (error) {
    debugPrint('读取开机自启动状态失败：$error');
    return false;
  } finally {
    launcher.dispose();
  }
}

/// 打开 / 关闭开机自启动，返回是否真的写成功。
Future<bool> setLaunchAtLogin(bool enabled) async {
  final launcher = _createLauncher();
  if (launcher == null) {
    return false;
  }
  try {
    return enabled ? launcher.enable() : launcher.disable();
  } catch (error) {
    debugPrint('设置开机自启动失败：$error');
    return false;
  } finally {
    launcher.dispose();
  }
}

// ---- 右下角系统通知 ----

// ---- 更新重启提示窗 ----

/// 用独立窗口播放视频（Windows/Linux/macOS）。返回是否成功开了新窗口。
///
/// 走 desktop_multi_window：新窗口是同一进程里的第二个引擎，入口参数是
/// `multi_window <windowId> <json>`（见 main()），所以那扇窗只跑播放页，
/// 不带主窗口的登录态、托盘、自绘标题栏。
Future<bool> openVideoWindow(String url, String? title) async {
  if (!isDesktopShell) {
    return false;
  }
  try {
    final controller = await DesktopMultiWindow.createWindow(
      jsonEncode(<String, dynamic>{'url': url, 'title': title}),
    );
    await controller.setTitle('视频播放 · 晏阳社区');
    await controller.setFrame(const Rect.fromLTWH(0, 0, 1000, 620));
    await controller.center();
    await controller.show();
    return true;
  } catch (error) {
    debugPrint('打开独立播放窗口失败，退回整页播放：$error');
    return false;
  }
}

/// 独立播放窗口里跑的应用（main 识别到 multi_window 参数时调用）。
Widget videoPlayerWindowApp({
  required int windowId,
  required Map<String, dynamic> argument,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  title: '视频播放',
  home: VideoPlayerPage(
    url: (argument['url'] as String?) ?? '',
    title: argument['title'] as String?,
    softwareSurface: true,
    // 独立窗口没有路由栈可退，返回按钮直接关掉这扇窗（这是唯一会用到
    // desktop_multi_window 的地方，所以它只出现在桌面实现文件里）。
    onClose: () => WindowController.fromWindowId(windowId).close(),
  ),
);

/// 从子窗口参数里取出播放地址。
Map<String, dynamic> parseVideoWindowArgument(String raw) {
  if (raw.isEmpty) {
    return const <String, dynamic>{};
  }
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
  } catch (_) {
    return const <String, dynamic>{};
  }
}

/// 更新重启提示窗的 PowerShell 脚本。**必须保持纯 ASCII**：Windows PowerShell 5.1
/// 按 ANSI 读 .ps1，非 ASCII 会变乱码；界面文字走环境变量传进去（环境变量是 UTF-16）。
const String _restartNoticeScript = r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$global:form = New-Object System.Windows.Forms.Form
$global:form.Text = $env:YCOMM_NOTICE_TITLE
$global:form.ClientSize = New-Object System.Drawing.Size(400, 150)
$global:form.StartPosition = 'CenterScreen'
$global:form.FormBorderStyle = 'FixedToolWindow'
$global:form.ShowInTaskbar = $true
$global:form.TopMost = $true
$global:label = New-Object System.Windows.Forms.Label
$global:label.Text = $env:YCOMM_NOTICE_BODY
$global:label.Dock = 'Fill'
$global:label.TextAlign = 'MiddleCenter'
$global:label.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
$global:form.Controls.Add($global:label)
$global:seenGone = $false
$global:deadline = (Get-Date).AddMinutes(15)
$global:timer = New-Object System.Windows.Forms.Timer
$global:timer.Interval = 1000
$global:timer.Add_Tick({
  $running = @(Get-Process -Name $env:YCOMM_NOTICE_PROC -ErrorAction SilentlyContinue).Count -gt 0
  if (-not $running) { $global:seenGone = $true }
  if ($global:seenGone -and $running) {
    $global:timer.Stop()
    $global:form.Close()
  } elseif ((Get-Date) -gt $global:deadline) {
    $global:timer.Stop()
    $global:form.Close()
  }
})
$global:timer.Start()
[System.Windows.Forms.Application]::Run($global:form)
''';

/// 更新重启时在最前面放一扇「正在重启」的小窗（Windows）。
///
/// 为什么不能由客户端自己画：静默安装要替换的正是客户端的文件，安装器会把本进程
/// 关掉。所以这扇窗交给一个独立的 PowerShell 进程——它只轮询客户端进程「消失→
/// 重新出现」，出现就自己关掉；15 分钟兜底，避免安装失败时窗口永远留着。
Future<void> showRestartNotice() async {
  if (!Platform.isWindows || !isDesktopShell) {
    return;
  }
  try {
    final processName = Platform.resolvedExecutable
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.exe$', caseSensitive: false), '');
    final directory = await Directory.systemTemp.createTemp('ycomm_restart');
    final script = File('${directory.path}\\notice.ps1');
    await script.writeAsString(_restartNoticeScript);
    await Process.start(
      'powershell.exe',
      <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        script.path,
      ],
      environment: <String, String>{
        ...Platform.environment,
        'YCOMM_NOTICE_TITLE': '正在重启晏阳社区',
        'YCOMM_NOTICE_BODY': '正在安装新版本，装好会自动打开，请稍候…',
        'YCOMM_NOTICE_PROC': processName,
      },
      mode: ProcessStartMode.detached,
    );
  } catch (error) {
    debugPrint('显示更新重启提示窗失败：$error');
  }
}

/// 弹一条系统通知。点通知会回到窗口。
Future<void> showDesktopNotification({
  required String title,
  required String body,
  VoidCallback? onClick,
}) async {
  if (!isDesktopShell) {
    return;
  }
  try {
    final notification = LocalNotification(title: title, body: body);
    notification.onClick = () => onClick?.call();
    await notification.show();
  } catch (error) {
    debugPrint('弹出系统通知失败：$error');
  }
}
