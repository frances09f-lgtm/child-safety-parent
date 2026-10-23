import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';
import 'zone_alerts.dart';

// Checks the two Android switches that decide whether alerts reach the
// phone while the app is closed: the notification permission (Android 13+)
// and the battery optimization exemption.
class BackgroundHealth {
  static const _channel = MethodChannel('app/background');

  static Future<bool> notificationsOn() async {
    if (kIsWeb) return true;
    try {
      final android = ZoneAlerts.local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> batteryUnrestricted() async {
    if (kIsWeb) return true;
    try {
      return await _channel.invokeMethod<bool>('isBatteryUnrestricted') ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestNotifications() async {
    if (kIsWeb) return;
    try {
      final android = ZoneAlerts.local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  // Opens the Android dialog that asks to stop battery limits for this app.
  static Future<void> requestBattery() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('requestBatteryExemption');
    } catch (_) {}
  }

  static Future<void> openNotificationSettings() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  // Asks for the battery exemption once, right after the first sign-in
  // setup. Settings shows a warning and a button if it is still off.
  static Future<void> askOnce() async {
    if (kIsWeb) return;
    try {
      if (await FamilyApi.storage.read(key: 'batteryAsked') == 'true') return;
      await FamilyApi.storage.write(key: 'batteryAsked', value: 'true');
      if (!await batteryUnrestricted()) await requestBattery();
    } catch (_) {}
  }

  static String? warning(bool notifications, bool battery) {
    if (!notifications && !battery) {
      return 'Notifications are off and battery limits are on. Alerts can be missed when the app is closed.';
    }
    if (!notifications) {
      return 'Notifications are off for this app. Alerts will not show until you allow them.';
    }
    if (!battery) {
      return 'Battery limits are on for this app. Android may stop background alert checks.';
    }
    return null;
  }
}

// Warning card for Settings. It shows only when notifications are off or
// battery limits apply, and checks again when the app is reopened.
class BackgroundWarning extends StatefulWidget {
  const BackgroundWarning({super.key});

  @override
  State<BackgroundWarning> createState() => _BackgroundWarningState();
}

class _BackgroundWarningState extends State<BackgroundWarning>
    with WidgetsBindingObserver {
  bool notifications = true, battery = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    final n = await BackgroundHealth.notificationsOn();
    final b = await BackgroundHealth.batteryUnrestricted();
    if (!mounted) return;
    setState(() {
      notifications = n;
      battery = b;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = BackgroundHealth.warning(notifications, battery);
    if (text == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alerts may not arrive when the app is closed',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: scheme.onErrorContainer)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!notifications)
                  FilledButton(
                    onPressed: () async {
                      await BackgroundHealth.requestNotifications();
                      if (!await BackgroundHealth.notificationsOn()) {
                        await BackgroundHealth.openNotificationSettings();
                      }
                      await load();
                    },
                    child: const Text('Allow notifications'),
                  ),
                if (!battery)
                  FilledButton(
                    onPressed: () async {
                      await BackgroundHealth.requestBattery();
                      await load();
                    },
                    child: const Text('Remove battery limit'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
