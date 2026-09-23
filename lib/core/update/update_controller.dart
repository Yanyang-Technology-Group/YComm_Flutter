// 更新检查的状态机。
//
// - 自动检查：启动时与回到前台时触发，6 小时内只真正请求一次，避免每次切后台都打接口。
// - 手动检查：「关于」页的「检查更新」，每次都真的请求，并把结果直接告诉用户。
//
// 只有发布构建（CI 注入了 YCOMM_VERSION）才比较版本；开发构建拿不到可比版本号，
// 不自动弹窗，只在手动检查时告诉用户线上最新版本是多少。
//
// 结论枚举 [UpdateStatus] 定义在 update_service.dart 里，解析层和状态层共用一套。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';
import '../network/community_api.dart';
import 'update_service.dart';

class UpdateState {
  const UpdateState({
    this.status,
    this.info,
    this.message,
    this.checking = false,
  });

  final UpdateStatus? status;

  /// 线上可下载的版本（[UpdateStatus.unavailable] 时也可能带着最新版本号）。
  final UpdateInfo? info;

  /// 无法判断或失败的原因。
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

  /// 用于「关于」页展示当前版本。
  String get currentLabel => appVersionLabel;

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
      await (await _prefs).setInt(
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
    // Web 随页面刷新更新，没有可下载的安装包。
    final platform = updatePlatformName();
    if (platform == null) {
      return const UpdateState(
        status: UpdateStatus.unavailable,
        message: 'Web 版本随页面刷新更新，无需检查。',
      );
    }

    final current = appVersionParts;
    final resolution = await _service.fetch(currentVersion: current);

    // 开发构建：不做「谁更新」的判断，只报出线上最新版本。
    if (current == null) {
      final latest = resolution.info;
      return UpdateState(
        status: UpdateStatus.unavailable,
        info: latest,
        message: latest == null
            ? (resolution.message ?? '当前是开发构建，且下载区里还没有 $platform 版本。')
            : '当前是开发构建，无法比较版本。线上最新为 ${latest.version}。',
      );
    }

    return switch (resolution.status) {
      UpdateStatus.found => UpdateState(
        status: UpdateStatus.found,
        info: resolution.info,
      ),
      UpdateStatus.upToDate => const UpdateState(status: UpdateStatus.upToDate),
      // 关键：拿不到版本信息时不要说「已是最新」，如实说明原因。
      UpdateStatus.unavailable => UpdateState(
        status: UpdateStatus.unavailable,
        message: resolution.message,
      ),
      UpdateStatus.failed => UpdateState(
        status: UpdateStatus.failed,
        message: resolution.message,
      ),
    };
  }

  /// 用户是否对这个版本点过「不再提醒」。
  Future<bool> isDismissed(String version) async =>
      (await _prefs).getString(dismissedKey) == version;

  Future<void> dismiss(String version) async =>
      (await _prefs).setString(dismissedKey, version);
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
