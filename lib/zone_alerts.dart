import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'api.dart';

@pragma('vm:entry-point')
void zoneDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await ZoneAlerts.checkAll();
      return true;
    } catch (_) {
      return false;
    }
  });
}

// Entry point of the always-on watcher (Android foreground service). It runs
// the same checks as the 15-minute job, every 30 seconds, so zone entries and
// exits, SOS, low battery and speed alerts arrive within about a minute of
// the child phone's report, also when the app is closed.
@pragma('vm:entry-point')
void liveServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  var busy = false;
  service.on('stop').listen((_) => service.stopSelf());
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (busy) return;
    busy = true;
    try {
      if (!await ZoneAlerts.wantsBackground()) {
        timer.cancel();
        service.stopSelf();
        return;
      }
      await ZoneAlerts.checkAll();
    } catch (_) {
    } finally {
      busy = false;
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
      if ((p['kind'] == 'zone' ||
              p['kind'] == 'speed' ||
              p['kind'] == 'alert') &&
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
    if (kIsWeb) return;
    if (!enabled && !await speedEnabled() && !await pushAlertsEnabled()) return;
    await initializeWorker();
    await Workmanager().registerPeriodicTask(
      job,
      job,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    try {
      await syncLive();
    } catch (_) {}
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

  static Future<bool> wantsBackground() async =>
      await isEnabled() || await speedEnabled() || await pushAlertsEnabled();

  // One round of background checks. Used by the 15-minute job and by the
  // always-on watcher. Each check reads its own cursor under a file lock, so
  // an alert is shown once even when both run at the same time.
  static Future<void> checkAll() async {
    if (!await wantsBackground() || !await FamilyApi.restore()) return;
    await initializeLocal();
    final devices = await FamilyApi.request('/api/devices') as List;
    try {
      await pollSpeed();
    } catch (_) {}
    try {
      await pollExtra();
    } catch (_) {}
    if (await isEnabled()) {
      for (final child in devices) {
        final data = await FamilyApi.request(
          '/api/zones/${Uri.encodeComponent(child['deviceId'])}',
        );
        await consume(
          Map<String, dynamic>.from(child),
          (data?['events'] as List?) ?? [],
        );
      }
    }
    await FamilyApi.storage.write(
      key: 'zoneLastCheck',
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<void> configureLive() async {
    await local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'live_monitor',
            'Alert watcher',
            description: 'Keeps safe-zone, SOS and speed alerts running',
            importance: Importance.low,
          ),
        );
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: liveServiceStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: 'live_monitor',
        initialNotificationTitle: 'Child Safety Parent',
        initialNotificationContent:
            'Watching for safe-zone, SOS and speed alerts',
        foregroundServiceNotificationId: 7701,
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  // Starts the always-on watcher when any alert is on, and stops it when all
  // are off. Must run while the app is on screen (Android blocks starting it
  // from the background).
  static Future<void> syncLive() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final want = await wantsBackground();
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (want) {
      await initializeLocal();
      await configureLive();
      if (!running) await service.startService();
    } else if (running) {
      service.invoke('stop');
    }
  }

  static String clock(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (d == null) return 'a recorded time';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  static Future<bool> pushAlertsEnabled() async =>
      await FamilyApi.storage.read(key: 'pushAlertsEnabled') == 'true';

  // Turns the background alert check (SOS, low battery and other alerts) on
  // or off. The check runs in the same Android WorkManager job as the
  // safe-zone and speed checks, so it also runs when the app is closed.
  static Future<void> setPushAlerts(bool on) async {
    await FamilyApi.storage.write(key: 'pushAlertsEnabled', value: '$on');
    if (kIsWeb) return;
    if (on) {
      await restoreSchedule();
    } else {
      if (!await isEnabled() && !await speedEnabled()) {
        await Workmanager().cancelByUniqueName(job);
      }
      try {
        await syncLive();
      } catch (_) {}
    }
  }

  static const _handledTypes = {
    'speed',
    'zone',
    'sos',
    'emergency',
    'low_battery',
    'battery',
  };

  /// SOS alerts from the server alert list with an id above [after], oldest
  /// first. Other alert types and entries without a numeric id are skipped.
  static List<Map<String, dynamic>> sosAlertsAfter(
    Iterable<dynamic> alerts,
    int after,
  ) {
    final out = alerts
        .whereType<Map>()
        .where(
          (a) =>
              a['id'] is num &&
              (a['id'] as num) > after &&
              (a['type']?.toString().toLowerCase() == 'sos' ||
                  a['type']?.toString().toLowerCase() == 'emergency'),
        )
        .map((a) => Map<String, dynamic>.from(a))
        .toList()
      ..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
    return out;
  }

  static Future<void> pollExtra({bool silent = false}) async {
    if (kIsWeb || !await pushAlertsEnabled()) return;
    final next = queue.then((_) => extraLocked(silent));
    queue = next.catchError((Object _) {});
    return next;
  }

  static Future<void> _notify(
    int id,
    String title,
    String body,
    String channel,
    String channelName,
    Map<String, dynamic> payload, {
    bool urgent = false,
  }) {
    return local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channelName,
          importance: urgent ? Importance.max : Importance.high,
          priority: urgent ? Priority.max : Priority.high,
          visibility: NotificationVisibility.private,
        ),
      ),
      payload: jsonEncode(payload),
    );
  }

  static Future<void> extraLocked(bool silent) async {
    final devices =
        (await FamilyApi.request('/api/devices').timeout(
                  const Duration(seconds: 20),
                )
                as List)
            .whereType<Map>()
            .toList();
    final config = await FamilyApi.request(
      '/api/alerts',
    ).timeout(const Duration(seconds: 20));
    final others =
        (config['alerts'] as List? ?? [])
            .whereType<Map>()
            .where(
              (a) =>
                  a['id'] is num &&
                  !_handledTypes.contains(a['type']?.toString().toLowerCase()),
            )
            .toList()
          ..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
    final reports = <String, Map>{};
    for (final d in devices) {
      final id = d['deviceId']?.toString();
      if (id == null) continue;
      try {
        final r = await FamilyApi.request(
          '/api/location/latest/${Uri.encodeComponent(id)}',
        ).timeout(const Duration(seconds: 20));
        if (r is Map) reports[id] = r;
      } catch (_) {}
    }
    final directory = await getApplicationSupportDirectory();
    final file = await File(
      '${directory.path}/zone-alert.lock',
    ).open(mode: FileMode.append);
    await file.lock(FileLock.exclusive);
    try {
      final account = accountKey();
      final cursorKey = 'alertCursor:$account';
      final previous = int.tryParse(
        await FamilyApi.storage.read(key: cursorKey) ?? '',
      );
      var latest = previous ?? 0;
      for (final a in others) {
        final id = (a['id'] as num).toInt();
        if (id <= latest) continue;
        if (!silent && previous != null) {
          await _notify(
            1100000000 + id,
            a['title']?.toString() ?? 'Family alert',
            a['body']?.toString() ?? 'New alert from a child phone.',
            'family_alerts',
            'Family safety alerts',
            {
              'kind': 'alert',
              'account': account,
              'device': a['deviceId'],
            },
          );
        }
        latest = id;
      }
      await FamilyApi.storage.write(key: cursorKey, value: '$latest');
      // SOS: notify once for each new SOS alert the server recorded. This
      // reads the alert list instead of the newest location report, so an SOS
      // is not lost when a normal report arrives right after it. It has its
      // own cursor, so older SOS alerts are never replayed after an update.
      final sosCursorKey = 'sosAlertCursor:$account';
      final sosPrevious = int.tryParse(
        await FamilyApi.storage.read(key: sosCursorKey) ?? '',
      );
      var sosLatest = sosPrevious ?? 0;
      for (final a in sosAlertsAfter(config['alerts'] as List? ?? [], 0)) {
        final id = (a['id'] as num).toInt();
        if (id <= sosLatest) continue;
        if (!silent && sosPrevious != null) {
          await _notify(
            1200000000 + id,
            a['title']?.toString() ?? 'SOS from a child phone',
            a['body']?.toString() ??
                'A child pressed the SOS button. Open the app to see the location.',
            'sos_alerts',
            'SOS alerts',
            {'kind': 'alert', 'account': account, 'device': a['deviceId']},
            urgent: true,
          );
        }
        sosLatest = id;
      }
      await FamilyApi.storage.write(key: sosCursorKey, value: '$sosLatest');
      for (final d in devices) {
        final device = d['deviceId']?.toString();
        if (device == null) continue;
        final name = d['childName']?.toString() ?? 'Child';
        final report = reports[device];
        // Low battery: notify once when the level falls to the threshold.
        final threshold = num.tryParse('${d['lowBatteryThreshold'] ?? 0}') ?? 0;
        final level = num.tryParse('${report?['battery'] ?? ''}');
        if (level != null) {
          final low = isLowBattery(threshold, level);
          final batKey = 'lowBattery:$account:$device';
          final batStored = await FamilyApi.storage.read(key: batKey);
          if (low) {
            if (batStored != 'low' && batStored != null && !silent) {
              await _notify(
                2100000000 + device.hashCode.abs() % 100000,
                'Low battery on $name',
                '$name\'s phone is at ${level.round()}%.',
                'family_alerts',
                'Family safety alerts',
                {'kind': 'alert', 'account': account, 'device': device},
              );
            }
            if (batStored != 'low') {
              await FamilyApi.storage.write(key: batKey, value: 'low');
            }
          } else if (batStored != 'ok') {
            await FamilyApi.storage.write(key: batKey, value: 'ok');
          }
        }
      }
    } finally {
      await file.unlock();
      await file.close();
    }
  }

  static bool isLowBattery(num threshold, num level) =>
      threshold > 0 && level <= threshold;

  static Future<void> disable() async {
    enabled = false;
    status = 'Off';
    pendingDevice.value = null;
    launchPayload = null;
    await FamilyApi.storage.write(key: 'zoneAlertsEnabled', value: 'false');
    if (!kIsWeb) {
      if (!await speedEnabled() && !await pushAlertsEnabled())
        await Workmanager().cancelByUniqueName(job);
      try {
        await syncLive();
      } catch (_) {}
      await local.cancelAll();
    }
  }

  static Future<void> disableAll() async {
    await FamilyApi.storage.write(key: 'speedPollingEnabled', value: 'false');
    await FamilyApi.storage.write(key: 'pushAlertsEnabled', value: 'false');
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
    else if (!enabled && !kIsWeb && !await pushAlertsEnabled()) {
      await Workmanager().cancelByUniqueName(job);
      try {
        await syncLive();
      } catch (_) {}
    }
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
            title:
                '${child['childName'] ?? 'Child'} ${entered ? 'entered' : 'left'} ${event['zoneName'] ?? 'a safe zone'}',
            body: 'Recorded at ${clock(event['fixAt'])}.',
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
