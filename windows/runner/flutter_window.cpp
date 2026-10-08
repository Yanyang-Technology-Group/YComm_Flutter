#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  taskbar_created_ = RegisterWindowMessageW(L"TaskbarCreated");
  tray_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "cn.yanyn.community/tray",
      &flutter::StandardMethodCodec::GetInstance());
  tray_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "disable") {
      RemoveTray();
      result->Success();
      return;
    }
    if (call.method_name() != "enable") {
      result->NotImplemented();
      return;
    }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) { result->Error("arguments", "Missing tray arguments"); return; }
    auto value = [&](const char* key) {
      auto it = args->find(flutter::EncodableValue(key));
      if (it == args->end()) return std::wstring();
      const auto* text = std::get_if<std::string>(&it->second);
      if (!text) return std::wstring();
      const int length = MultiByteToWideChar(CP_UTF8, 0, text->data(),
                                            static_cast<int>(text->size()), nullptr, 0);
      std::wstring wide(length, L'\0');
      MultiByteToWideChar(CP_UTF8, 0, text->data(), static_cast<int>(text->size()),
                          wide.data(), length);
      return wide;
    };
    tray_system_ = value("system");
    tray_version_ = value("version");
    HICON icon = static_cast<HICON>(LoadImageW(nullptr, value("icon").c_str(),
                         IMAGE_ICON, GetSystemMetrics(SM_CXSMICON),
                         GetSystemMetrics(SM_CYSMICON), LR_LOADFROMFILE));
    if (!icon) { result->Error("icon", "Unable to load tray icon"); return; }
    HICON previous = tray_data_.hIcon;
    tray_data_.cbSize = sizeof(tray_data_);
    tray_data_.hWnd = GetHandle();
    tray_data_.uID = 1;
    tray_data_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    tray_data_.uCallbackMessage = WM_APP + 42;
    tray_data_.hIcon = icon;
    const auto tooltip = value("tooltip");
    wcsncpy_s(tray_data_.szTip, tooltip.c_str(), _TRUNCATE);
    bool ok = Shell_NotifyIconW(tray_visible_ ? NIM_MODIFY : NIM_ADD, &tray_data_) != FALSE;
    if (!ok && tray_visible_) ok = Shell_NotifyIconW(NIM_ADD, &tray_data_) != FALSE;
    tray_visible_ = ok;
    if (previous) DestroyIcon(previous);
    if (ok) result->Success(); else result->Error("tray", "Unable to create tray icon");
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTray();
  tray_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (taskbar_created_ != 0 && message == taskbar_created_ && tray_visible_) {
    Shell_NotifyIconW(NIM_ADD, &tray_data_);
    return 0;
  }
  if (message == WM_APP + 43) {
    ShowMainWindow();
    if (tray_channel_) tray_channel_->InvokeMethod("show", nullptr);
    return 0;
  }
  if (message == WM_APP + 42) {
    if (lparam == WM_LBUTTONUP || lparam == WM_LBUTTONDBLCLK) {
      ShowMainWindow();
      tray_channel_->InvokeMethod("show", nullptr);
    } else if (lparam == WM_RBUTTONUP) {
      HMENU menu = CreatePopupMenu();
      AppendMenuW(menu, MF_STRING | MF_GRAYED, 0, tray_system_.c_str());
      AppendMenuW(menu, MF_STRING | MF_GRAYED, 0, tray_version_.c_str());
      AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
      AppendMenuW(menu, MF_STRING, 1, L"显示主窗口");
      AppendMenuW(menu, MF_STRING, 2, L"检查更新");
      AppendMenuW(menu, MF_STRING, 3, L"退出");
      POINT position;
      GetCursorPos(&position);
      SetForegroundWindow(hwnd);
      const UINT action = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
                                        position.x, position.y, 0, hwnd, nullptr);
      DestroyMenu(menu);
      PostMessageW(hwnd, WM_NULL, 0, 0);
      if (action == 1 || action == 2) ShowMainWindow();
      if (action != 0) tray_channel_->InvokeMethod(
          action == 1 ? "show" : action == 2 ? "update" : "exit", nullptr);
    }
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RemoveTray() {
  if (tray_visible_) Shell_NotifyIconW(NIM_DELETE, &tray_data_);
  tray_visible_ = false;
  if (tray_data_.hIcon) DestroyIcon(tray_data_.hIcon);
  tray_data_ = {};
}

void FlutterWindow::ShowMainWindow() {
  const HWND hwnd = GetHandle();
  LONG_PTR style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);
  SetWindowLongPtrW(hwnd, GWL_EXSTYLE, (style & ~WS_EX_TOOLWINDOW) | WS_EX_APPWINDOW);
  ShowWindow(hwnd, IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(hwnd);
}
