#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Video processes have their own window; the main client has one tray owner.
  HANDLE main_instance = nullptr;
  if (command_line_arguments.empty() || command_line_arguments.front() != "video-window") {
    const bool relaunch = !command_line_arguments.empty() &&
                         command_line_arguments.front() == "internal-relaunch";
    main_instance = CreateMutexW(nullptr, TRUE, L"Local\\YComm.MainWindow");
    if (main_instance && GetLastError() == ERROR_ALREADY_EXISTS) {
      if (relaunch) {
        const DWORD status = WaitForSingleObject(main_instance, 10000);
        if (status != WAIT_OBJECT_0 && status != WAIT_ABANDONED) {
          CloseHandle(main_instance);
          ::CoUninitialize();
          return EXIT_FAILURE;
        }
      } else {
        HWND existing = nullptr;
        for (int attempt = 0; attempt < 20 && !existing; ++attempt) {
          EnumWindows([](HWND hwnd, LPARAM data) -> BOOL {
            if (!GetPropW(hwnd, L"YComm.MainWindow")) return TRUE;
            *reinterpret_cast<HWND*>(data) = hwnd;
            return FALSE;
          }, reinterpret_cast<LPARAM>(&existing));
          if (!existing) Sleep(100);
        }
        if (existing) {
          AllowSetForegroundWindow(ASFW_ANY);
          PostMessageW(existing, WM_APP + 43, 0, 0);
        }
        CloseHandle(main_instance);
        ::CoUninitialize();
        return EXIT_SUCCESS;
      }
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"晏阳社区", origin, size)) {
    if (main_instance) {
      ReleaseMutex(main_instance);
      CloseHandle(main_instance);
    }
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  if (main_instance) SetPropW(window.GetHandle(), L"YComm.MainWindow", reinterpret_cast<HANDLE>(1));
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (main_instance) {
    ReleaseMutex(main_instance);
    CloseHandle(main_instance);
  }
  return EXIT_SUCCESS;
}
