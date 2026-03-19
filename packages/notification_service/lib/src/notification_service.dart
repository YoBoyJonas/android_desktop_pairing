import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';

// Action identifier constants
const String kDismissAction = 'dismiss';
const String kOpenAppAction = 'open_app';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init({
    required void Function(String actionId) onAction,
  }) async {
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Desktop Server',
      appUserModelId: 'com.dagos.androiddesktoppairing',
      guid: '03bf3923-8a74-4679-ba31-adaf7624da0a', 
    );

    await _plugin.initialize(
      settings: InitializationSettings(windows: windowsSettings),
      onDidReceiveNotificationResponse: (response) {
        final actionId = response.actionId ?? kOpenAppAction;
        onAction(actionId);
      },
    );
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String messagePreview,
  }) async {
    final windowsDetails = WindowsNotificationDetails(
      actions: [
        const WindowsAction(
          content: 'Open App',
          arguments: kOpenAppAction,
        ),
        const WindowsAction(
          content: 'Dismiss',
          arguments: kDismissAction,
        ),
      ],
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000, 
      title: 'New message from $senderName',
      body: messagePreview,
      notificationDetails: NotificationDetails(windows: windowsDetails),
    );
  }
}