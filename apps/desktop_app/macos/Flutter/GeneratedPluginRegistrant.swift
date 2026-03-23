//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import flutter_local_notifications
import network_info_plus
import nsd_macos
import screen_retriever_macos
import tray_manager
import window_manager
import window_to_front

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FlutterLocalNotificationsPlugin.register(with: registry.registrar(forPlugin: "FlutterLocalNotificationsPlugin"))
  NetworkInfoPlusPlugin.register(with: registry.registrar(forPlugin: "NetworkInfoPlusPlugin"))
  NsdMacosPlugin.register(with: registry.registrar(forPlugin: "NsdMacosPlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  TrayManagerPlugin.register(with: registry.registrar(forPlugin: "TrayManagerPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
  WindowToFrontPlugin.register(with: registry.registrar(forPlugin: "WindowToFrontPlugin"))
}
