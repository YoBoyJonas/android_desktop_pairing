import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService extends TrayListener {
  static final TrayService instance = TrayService._();
  TrayService._();

  Future<void> init({required String iconPath}) async {
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('desktop server');
    final Menu menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: 'Show App'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Exit'),
      ],
    );
    
    await trayManager.setContextMenu(menu);
    trayManager.addListener(instance);
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.setPreventClose(false);
      windowManager.close();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }
}