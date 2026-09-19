// 更新检查的状态机。
//
// - 自动检查：启动时与回到前台时触发，6 小时内只真正请求一次，避免每次切后台都打接口。
// - 手动检查：「关于」页的「检查更新」，每次都真的请求，并把结果直接告诉用户。
//
// 只有发布构建（CI 注入了 YCOMM_VERSION）才比较版本；开发构建拿不到可比版本号，
// 不自动弹窗，只在手动检查时告诉用户线上最新版本是多少。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';
import '../network/community_api.dart';
import 'update_service.dart';

enum UpdateStatus {
  /// 线上有更新的版本。
  found,

  /// 已是最新。
  upToDate,

  /// 当前平台不参与自动更新，或开发构建无法比较。
  unsupported,

  /// 请求失败。
  failed,
}

class UpdateState {
  const UpdateState({
    this.status,
    this.info,
    this.message,
    this.checking = false,
  });

  final UpdateStatus? status;

  /// 线上可下载的版本（[UpdateStatus.unsupported] 时也可能带着最新版本号）。
  final UpdateInfo? info;

  /// 不支持或失败的原因。
  final String? message;

  final bool checking;
}

class UpdateController extends Notifier<UpdateState> {
  /// 用户点过「不再提醒」的版本号。
  static const dismissedKey = 'ycomm_update_dismissed_version';

  /// 上次自动检查的时间戳（毫秒）。
  static const lastCheckKey = 'ycomm_update_last_check';

  /// 自动检查的最小间隔。
  static const autoCheckInterval = Duration(hours: 6);

  @override
  UpdateState build() => const UpdateState();

  UpdateService get _service => UpdateService(ref.read(communityProvider));

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// 手动检查：每次都真的请求。
  Future<UpdateState> check() => _run();

  /// 自动检查：距上次不足 [autoCheckInterval] 就跳过，返回 null 表示「没查」。
  Future<UpdateState?> autoCheck() async {
    final prefs = await _prefs;
    final last = prefs.getInt(lastCheckKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    if (elapsed < autoCheckInterval.inMilliseconds) {
      return null;
    }
    return _run();
  }

  Future<UpdateState> _run() async {
    if (state.checking) {
      return state;
    }
    state = UpdateState(status: state.status, info: state.info, checking: true);

    UpdateState next;
    try {
      next = await _resolve();
      final prefs = await _prefs;
      await prefs.setInt(
        lastCheckKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (error) {
      next = UpdateState(status: UpdateStatus.failed, message: '$error');
    }
    state = next;
    return next;
  }

  Future<UpdateState> _resolve() async {
    // Web 端随页面刷新更新，没有可下载的安装包。
    final platform = updatePlatformName();
    if (platform == null) {
      return const UpdateState(
        status: UpdateStatus.unsupported,
        message: '当前平台不支持自动更新，请到社区下载区查看最新版本。',
      );
    }

    final current = appVersionParts;
    if (current == null) {
      // 开发构建：报出线上最新版本，但不做「谁更新」的判断。
      final latest = await _service.fetch(currentVersion: null);
      return UpdateState(
        status: UpdateStatus.unsupported,
        info: latest,
        message: latest == null
            ? '当前是开发构建，且下载区里还没有 $platform 版本。'
            : '当前是开发构建，无法比较版本。线上最新为 ${latest.version}。',
      );
    }

    final info = await _service.fetch(currentVersion: current);
    return info == null
        ? const UpdateState(status: UpdateStatus.upToDate)
        : UpdateState(status: UpdateStatus.found, info: info);
  }

  /// 用户是否对这个版本点过「不再提醒」。
  Future<bool> isDismissed(String version) async =>
      (await _prefs).getString(dismissedKey) == version;

  Future<void> dismiss(String version) async =>
      (await _prefs).setString(dismissedKey, version);

  /// 用于「关于」页展示当前版本。
  String get currentLabel => appVersionLabel;
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
