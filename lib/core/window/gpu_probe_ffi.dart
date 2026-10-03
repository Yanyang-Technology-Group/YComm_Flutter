// Windows 上探测「这台机器到底能不能用显卡渲染」。
//
// 只看平台是不够的：虚拟机、远程桌面、驱动没装好的机器上引擎会退化成软件渲染，
// 这时候还把「GPU 加速」显示成开启就是骗人。这里直接问 D3D11：用
// D3D_DRIVER_TYPE_HARDWARE 建一次设备，建得出来才算有硬件加速可用。
import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _D3D11CreateDeviceNative = Int32 Function(
  Pointer<Void> adapter,
  Int32 driverType,
  Pointer<Void> software,
  Uint32 flags,
  Pointer<Int32> featureLevels,
  Uint32 featureLevelCount,
  Uint32 sdkVersion,
  Pointer<Pointer<Void>> device,
  Pointer<Int32> featureLevel,
  Pointer<Pointer<Void>> context,
);
typedef _D3D11CreateDeviceDart = int Function(
  Pointer<Void> adapter,
  int driverType,
  Pointer<Void> software,
  int flags,
  Pointer<Int32> featureLevels,
  int featureLevelCount,
  int sdkVersion,
  Pointer<Pointer<Void>> device,
  Pointer<Int32> featureLevel,
  Pointer<Pointer<Void>> context,
);

typedef _ReleaseNative = IntPtr Function(Pointer<Void> object);
typedef _ReleaseDart = int Function(Pointer<Void> object);

const int _driverTypeHardware = 1; // D3D_DRIVER_TYPE_HARDWARE
const int _d3d11SdkVersion = 7;

/// 有可用的 D3D11 硬件设备时为 true（Win7+ 的 d3d11.dll 一定存在，
/// 拿不到函数或建不出硬件设备都算不支持）。
bool windowsHasHardwareGpu() {
  _D3D11CreateDeviceDart? createDevice;
  try {
    createDevice = DynamicLibrary.open('d3d11.dll')
        .lookupFunction<_D3D11CreateDeviceNative, _D3D11CreateDeviceDart>(
          'D3D11CreateDevice',
        );
  } catch (_) {
    return false;
  }

  final device = calloc<Pointer<Void>>();
  final featureLevel = calloc<Int32>();
  final context = calloc<Pointer<Void>>();
  try {
    final hr = createDevice(
      nullptr,
      _driverTypeHardware,
      nullptr,
      0,
      nullptr,
      0,
      _d3d11SdkVersion,
      device,
      featureLevel,
      context,
    );
    if (hr != 0) {
      return false;
    }
    _releaseCom(device.value);
    _releaseCom(context.value);
    return true;
  } finally {
    calloc.free(device);
    calloc.free(featureLevel);
    calloc.free(context);
  }
}

/// IUnknown::Release（COM 虚表第 3 个槽位）。探测完就把设备放掉，
/// 不能因为我们只想问一句就把显卡设备一直开着。
void _releaseCom(Pointer<Void> object) {
  if (object == nullptr) return;
  final vtable = object
      .cast<Pointer<Pointer<NativeFunction<_ReleaseNative>>>>()
      .value;
  final release = vtable[2].asFunction<_ReleaseDart>();
  release(object);
}
