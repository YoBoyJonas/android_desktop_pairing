import 'package:flutter/material.dart';
import 'package:notification_service/notification_service.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/server_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await TrayService.instance.init(
    iconPath: 'assets/dagosErp.ico',
  );
  WindowOptions windowOptions = const WindowOptions(
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await NotificationService.instance.init(
    onAction: (actionId) {
      if (actionId == kOpenAppAction) {
        windowManager.focus();
      }
    },
  );

  runApp(const DesktopApp());
}

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: ServerScreen());
  }
}

