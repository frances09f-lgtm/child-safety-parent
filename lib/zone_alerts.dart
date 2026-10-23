import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'api.dart';

@pragma('vm:entry-point')
void zoneDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      if ((!await ZoneAlerts.isEnabled() && !await ZoneAlerts.speedEnabled()) ||
          !await FamilyApi.restore())
        return true;
      await ZoneAlerts.initializeLocal();
      final devices = await FamilyApi.request('/api/devices') as List;
      await ZoneAlerts.pollSpeed();
      if (await ZoneAlerts.isEnabled())
        for (final child in devices) {
          final data = await FamilyApi.request(
            '/api/zones/${Uri.encodeComponent(child['deviceId'])}',
          );
          await ZoneAlerts.consume(
            Map<String, dynamic>.from(child),
            (data?['events'] as List?) ?? [],
          );
        }
      await FamilyApi.storage.write(
        key: 'zoneLastCheck',
        value: DateTime.now().toUtc().toIso8601String(),
      );
      return true;
    } catch (_) {
      return false;
    }
  });
}

class ZoneAlerts {
  static const job = 'safe-zone-poll';
  static final local = FlutterLocalNotificationsPlugin();
  static final pendingDevice = ValueNotifier<String?>(null);
  static bool enabled = false, changing = false;
  static bool workerReady = false;
  static String status = 'Off';
  static String? launchPayload;
  static int pendingTab = 1;
  static Future<bool> speedEnabled() async =>
      await FamilyApi.storage.read(key: 'speedPollingEnabled') == 'true';
  static Future<void> queue = Future.value();
  static Future<bool> isEnabled() async =>
      await FamilyApi.storage.read(key: 'zoneAlertsEnabled') == 'true';
  static String accountKey() =>
      base64Url.encode(utf8.encode('${FamilyApi.server}|${FamilyApi.email}'));
  static Future<void> initializeLocal() async {
    if (kIsWeb) return;
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_zone_alert'),
      ),
      onDidReceiveNotificationResponse: (r) => receive(r.payload),
    );
    await local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'zone_crossings',
            'Safe-zone crossings',
            description: 'Confirmed entries and exits, checked periodically',
            importance: Importance.high,
          ),
        );
  }

  static void receive(String? payload) {
    if (FamilyApi.email.isEmpty) {
      launchPayload = payload;
      return;
    }
    try {
      final p = jsonDecode(payload ?? '{}');
      if ((p['kind'] == 'zone' || p['kind'] == 'speed') &&
          p['account'] == accountKey()) {
        pendingTab = p['kind'] == 'speed' ? 3 : 1;
        pendingDevice.value = p['device'] as String;
      }
    } catch (_) {}
  }

  static Future<void> initialize() async {
    if (kIsWeb) return;
    await initializeLocal();
    await initializeWorker();
    enabled = await isEnabled();
    status = enabled ? 'Enabled - background checks can be delayed' : 'Off';
    final launch = await local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true)
      receive(launch?.notificationResponse?.payload);
  }

  static Future<void> initializeWorker() async {
    if (workerReady) return;
    await Workmanager()
        .initialize(zoneDispatcher)
        .timeout(const Duration(seconds: 15));
    workerReady = true;
  }

  static Future<void> restoreSchedule() async {
    if (launchPayload != null) {
      final payload = launchPayload;
      launchPayload = null;
      receive(payload);
    }
    if ((!enabled && !await speedEnabled()) || kIsWeb) return;
    await initializeWorker();
    await Workmanager().registerPeriodicTask(
      job,
      job,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> enable(List<Map<String, dynamic>> children) async {
    if (kIsWeb) {
      status = 'Available in Android app';
      return;
    }
    status = 'Preparing Android notifications...';
    try {
      await initializeLocal().timeout(const Duration(seconds: 15));
    } catch (_) {
      status = 'Android notification setup failed. Restart the app and retry.';
      return;
    }
    status = 'Waiting for Android notification permission...';
    final android = local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await android?.requestNotificationsPermission();
      if (await android?.areNotificationsEnabled() != true) {
        status = 'Notifications blocked. Allow them in Android app Settings.';
        return;
      }
    } catch (_) {
      status = 'Could not request Android notification permission.';
      return;
    }
    status = 'Loading safe-zone history...';
    try {
      for (final child in children) {
        final data = await FamilyApi.request(
          '/api/zones/${Uri.encodeComponent(child['deviceId'])}',
        ).timeout(const Duration(seconds: 20));
        await consume(
          child,
          (data?['events'] as List?) ?? [],
          baseline: true,
        ).timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      status =
          'Could not load zone history. Check server connection and retry.';
      return;
    }
    status = 'Starting background checks...';
    try {
      await initializeWorker();
    } catch (_) {
      status = 'Background setup failed. Restart the app and retry.';
      return;
    }
    await FamilyApi.storage.write(key: 'zoneAlertsEnabled', value: 'true');
    enabled = true;
    try {
      await restoreSchedule().timeout(const Duration(seconds: 15));
      status = 'Enabled - background checks can be delayed';
    } catch (_) {
      status = 'Enabled while open; background setup needs retry.';
    }
  }

  static Future<void> disable() async {
    enabled = false;
    status = 'Off';
    pendingDevice.value = null;
    launchPayload = null;
    await FamilyApi.storage.write(key: 'zoneAlertsEnabled', value: 'false');
    if (!kIsWeb) {
      if (!await speedEnabled()) await Workmanager().cancelByUniqueName(job);
      await local.cancelAll();
    }
  }

  static Future<void> disableAll() async {
    await FamilyApi.storage.write(key: 'speedPollingEnabled', value: 'false');
    await disable();
  }

  static Future<bool> configureSpeed(String device, int limit) async {
    final key = 'speedDevices:${accountKey()}';
    final devices = Set<String>.from(
      jsonDecode(await FamilyApi.storage.read(key: key) ?? '[]'),
    );
    if (limit <= 0) {
      devices.remove(device);
    } else {
      await initializeLocal();
      final android = local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      if (await android?.areNotificationsEnabled() != true) return false;
      await pollSpeed(baseline: true);
      devices.add(device);
    }
    await FamilyApi.storage.write(
      key: key,
      value: jsonEncode(devices.toList()),
    );
    await FamilyApi.storage.write(
      key: 'speedPollingEnabled',
      value: '${devices.isNotEmpty}',
    );
    if (devices.isNotEmpty)
      await restoreSchedule();
    else if (!enabled && !kIsWeb)
      await Workmanager().cancelByUniqueName(job);
    return true;
  }

  static Future<void> pollSpeed({bool baseline = false}) async {
    if (kIsWeb || (!baseline && !await speedEnabled())) return;
    final next = queue.then((_) => speedLocked(baseline));
    queue = next.catchError((Object _) {});
    return next;
  }

  static Future<void> speedLocked(bool baseline) async {
    final config = await FamilyApi.request(
      '/api/alerts',
    ).timeout(const Duration(seconds: 20));
    final events =
        (config['alerts'] as List? ?? [])
            .whereType<Map>()
            .where((a) => a['type'] == 'speed' && a['id'] is num)
            .toList()
          ..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
    final directory = await getApplicationSupportDirectory();
    final file = await File(
      '${directory.path}/zone-alert.lock',
    ).open(mode: FileMode.append);
    await file.lock(FileLock.exclusive);
    try {
      final key = 'speedCursor:${accountKey()}';
      final stored = await FamilyApi.storage.read(key: key);
      final previous = int.tryParse(stored ?? '');
      var latest = previous ?? 0;
      final devices = Set<String>.from(
        jsonDecode(
          await FamilyApi.storage.read(key: 'speedDevices:${accountKey()}') ??
              '[]',
        ),
      );
      for (final a in events) {
        final id = (a['id'] as num).toInt();
        if (id <= latest) continue;
        if (!baseline &&
            previous != null &&
            devices.contains(a['deviceId']) &&
            await speedEnabled()) {
          await local.show(
            id: 1000000000 + id,
            title: a['title']?.toString() ?? 'Speed alert',
            body:
                '${a['body'] ?? 'Recorded speed alert'} Recorded: ${a['reportedAt'] ?? 'unknown time'}.',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'speed_alerts',
                'Speed alerts',
                importance: Importance.high,
                priority: Priority.high,
                visibility: NotificationVisibility.private,
              ),
            ),
            payload: jsonEncode({
              'kind': 'speed',
              'account': accountKey(),
              'device': a['deviceId'],
            }),
          );
        }
        latest = id;
      }
      await FamilyApi.storage.write(key: key, value: '$latest');
    } finally {
      await file.unlock();
      await file.close();
    }
  }

  static Future<void> consume(
    Map<String, dynamic> child,
    List events, {
    bool baseline = false,
  }) {
    final next = queue.then(
      (_) => consumeLocked(child, events, baseline: baseline),
    );
    queue = next.catchError((Object _) {});
    return next;
  }

  static Future<void> consumeLocked(
    Map<String, dynamic> child,
    List events, {
    bool baseline = false,
  }) async {
    if (kIsWeb || (!baseline && !await isEnabled())) return;
    final directory = await getApplicationSupportDirectory();
    final file = await File(
      '${directory.path}/zone-alert.lock',
    ).open(mode: FileMode.append);
    await file.lock(FileLock.exclusive);
    try {
      final key = 'zoneCursor:${accountKey()}:${child['deviceId']}';
      final stored = await FamilyApi.storage.read(key: key);
      final previous = int.tryParse(stored ?? '');
      final sorted =
          events.whereType<Map>().where((e) => e['id'] is num).toList()
            ..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
      var latest = previous ?? 0;
      for (final event in sorted) {
        final id = (event['id'] as num).toInt();
        if (id <= latest) continue;
        if (!baseline && previous != null && await isEnabled()) {
          final entered = event['entered'] == true;
          await local.show(
            id: id,
            title: 'Safe-zone ${entered ? 'entry' : 'exit'}',
            body:
                '${child['childName'] ?? 'Child'} ${entered ? 'entered' : 'left'} ${event['zoneName'] ?? 'a safe zone'} at ${event['fixAt'] ?? 'recorded time'}.',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'zone_crossings',
                'Safe-zone crossings',
                importance: Importance.high,
                priority: Priority.high,
                visibility: NotificationVisibility.private,
              ),
            ),
            payload: jsonEncode({
              'kind': 'zone',
              'account': accountKey(),
              'device': child['deviceId'],
              'event': id,
            }),
          );
        }
        latest = id;
      }
      await FamilyApi.storage.write(key: key, value: '$latest');
    } finally {
      await file.unlock();
      await file.close();
    }
  }
}
