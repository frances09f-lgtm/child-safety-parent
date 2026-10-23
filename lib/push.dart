import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';
import 'zone_alerts.dart';
import 'background_health.dart';

// Runs when a push message arrives while the app is closed or in the
// background. A message that carries a notification block is shown by Android
// itself; a data-only message is turned into a notification here.
@pragma('vm:entry-point')
Future<void> parentBackgroundMessage(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  if (message.notification != null) return;
  final title = message.data['title']?.toString();
  final body = message.data['body']?.toString();
  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return;
  }
  await ZoneAlerts.initializeLocal();
  await ZoneAlerts.local.show(
    id: message.messageId.hashCode,
    title: title ?? 'Family safety alert',
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'family_alerts',
        'Family safety alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

class ParentPush {
  static String status = 'Notifications not enabled';
  static String? token;
  static StreamSubscription<String>? changes;
  static StreamSubscription<RemoteMessage>? messages;
  static final local = FlutterLocalNotificationsPlugin();
  static Future<void> enable() async {
    if (kIsWeb) {
      status = 'Push available in Android app';
      return;
    }
    try {
      if (Firebase.apps.isEmpty)
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: FamilyApi.key,
            appId: '1:509368336413:android:90f647c88882d7e40a46f4',
            messagingSenderId: '509368336413',
            projectId: 'app-testing-2cdba',
          ),
        );
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await ZoneAlerts.initializeLocal();
      await local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'family_alerts',
              'Family safety alerts',
              description: 'SOS, safe zone, low battery and speed reports',
              importance: Importance.high,
            ),
          );
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        status = 'Notifications denied in Android Settings';
        return;
      }
      FirebaseMessaging.onBackgroundMessage(parentBackgroundMessage);
      // Background check: SOS, low battery and other alerts are also read
      // from the server every 15 minutes while the app is closed.
      try {
        await ZoneAlerts.setPushAlerts(true);
        await ZoneAlerts.pollExtra(silent: true);
      } catch (_) {}
      // Safe-zone entry and exit alerts are on by default. They stay off only
      // if the owner turned the switch off in Settings.
      try {
        if (await FamilyApi.storage.read(key: 'zoneAlertsEnabled') == null &&
            !ZoneAlerts.changing) {
          final list = await FamilyApi.request('/api/devices') as List;
          await ZoneAlerts.enable(
            list
                .whereType<Map>()
                .map((c) => Map<String, dynamic>.from(c))
                .toList(),
          );
        }
      } catch (_) {}
      token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        status = 'Could not register notifications';
        return;
      }
      await FamilyApi.request(
        '/api/alerts/token',
        method: 'POST',
        data: {'token': token},
      );
      final config = await FamilyApi.request('/api/alerts');
      status = config['pushConfigured'] == true
          ? 'Push registered on this phone'
          : 'Phone registered; server push setup pending';
      await changes?.cancel();
      changes = FirebaseMessaging.instance.onTokenRefresh.listen((value) async {
        token = value;
        try {
          await FamilyApi.request(
            '/api/alerts/token',
            method: 'POST',
            data: {'token': value},
          );
        } catch (_) {
          status = 'Notification registration needs retry';
        }
      });
      await messages?.cancel();
      messages = FirebaseMessaging.onMessage.listen((message) {
        local.show(
          id: message.messageId.hashCode,
          title: message.notification?.title,
          body: message.notification?.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'family_alerts',
              'Family safety alerts',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      });
      await BackgroundHealth.askOnce();
    } catch (_) {
      status =
          'Could not register push. Check network and Google Play services.';
    }
  }

  static Future<void> disable() async {
    try {
      await ZoneAlerts.setPushAlerts(false);
    } catch (_) {}
    if (token != null) {
      await FamilyApi.request(
        '/api/alerts/token',
        method: 'DELETE',
        data: {'token': token},
      );
    }
    await changes?.cancel();
    await messages?.cancel();
    if (!kIsWeb && Firebase.apps.isNotEmpty)
      await FirebaseMessaging.instance.deleteToken();
    if (!kIsWeb && Firebase.apps.isNotEmpty)
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
    token = null;
    status = 'Notifications disabled';
  }
}
