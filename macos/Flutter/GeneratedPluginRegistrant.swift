//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import local_notifier
import screen_retriever_macos
import shared_preferences_foundation
import url_launcher_macos
import webview_all_wkwebview
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  LocalNotifierPlugin.register(with: registry.registrar(forPlugin: "LocalNotifierPlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
  WebviewAllWKWebViewPlugin.register(with: registry.registrar(forPlugin: "WebviewAllWKWebViewPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
