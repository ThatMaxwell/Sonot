import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// System notifications for Sonot Code: "done", "needs you", and the
/// agent's own `notify` tool. Urgent ones are forced through: an urgent
/// toast that breaks through Do Not Disturb on Windows, a critical
/// notification on Linux, and a full-screen alarm-style alert on Android.
class Notifier {
  Notifier._();
  static final instance = Notifier._();

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Set from Settings: notifications on at all, and urgent ones allowed.
  bool Function() enabled = () => true;
  bool Function() urgentAllowed = () => true;
  bool _ready = false;
  int _id = 1;

  static const _normal = AndroidNotificationDetails(
    'sonot_code',
    'Sonot Code',
    channelDescription: 'When a task finishes or needs you',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _urgent = AndroidNotificationDetails(
    'sonot_code_urgent',
    'Sonot Code: urgent',
    channelDescription: 'Urgent alerts the agent sends you',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
    visibility: NotificationVisibility.public,
    ticker: 'Sonot',
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          linux: LinuxInitializationSettings(defaultActionName: 'Open Sonot'),
          windows: WindowsInitializationSettings(
            appName: 'Sonot',
            appUserModelId: 'ThatMaxwell.Sonot.App.1',
            // Fixed so Windows keeps one notification identity for Sonot.
            guid: '5d1f0c3e-7a8b-4c2d-9e6f-1a2b3c4d5e6f',
          ),
        ),
      );
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
        await android?.requestFullScreenIntentPermission();
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Shows a notification. Returns false when the system has none.
  Future<bool> show(String title, String body, {bool urgent = false}) async {
    if (!enabled()) return false;
    urgent = urgent && urgentAllowed();
    await init();
    if (!_ready) return false;
    try {
      await _plugin.show(
        id: _id++,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: urgent ? _urgent : _normal,
          linux: LinuxNotificationDetails(urgency: urgent ? LinuxNotificationUrgency.critical : LinuxNotificationUrgency.normal),
          windows: WindowsNotificationDetails(scenario: urgent ? WindowsNotificationScenario.urgent : null),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Notification failed: $e');
      return false;
    }
  }
}
