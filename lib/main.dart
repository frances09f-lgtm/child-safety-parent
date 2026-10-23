import 'update/app_update.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import 'api.dart';
import 'pally.dart';
import 'detail_reports.dart';
import 'push.dart';
import 'zone_alerts.dart';
import 'history_today.dart';
import 'activity.dart';
import 'live/bug_report.dart';

Color get green =>
    ParentTheme.dark.value ? const Color(0xff8fd8c2) : const Color(0xff2f6b5e);
Color get tonal =>
    ParentTheme.dark.value ? const Color(0xff1a2422) : const Color(0xffeaf1ea);
Color get danger =>
    ParentTheme.dark.value ? const Color(0xffff8a80) : const Color(0xffb3261e);
Color get amber =>
    ParentTheme.dark.value ? const Color(0xff2a2312) : const Color(0xfffbf1d9);
Color get onAmber =>
    ParentTheme.dark.value ? const Color(0xfff2d48a) : const Color(0xff6b4e12);
Color get ink => ParentTheme.dark.value ? Color(0xffe9f1ec) : Color(0xff14201b);
Color get muted =>
    ParentTheme.dark.value ? Color(0xff9aa8a2) : Color(0xff5c6b63);
Color get pale =>
    ParentTheme.dark.value ? Color(0xff0b0f10) : Color(0xfff3f6f1);
Color get surface => ParentTheme.dark.value ? Color(0xff141a1b) : Colors.white;
Color get edge =>
    ParentTheme.dark.value ? Color(0xff24312e) : Color(0xffdce5dd);
Color get soft =>
    ParentTheme.dark.value ? Color(0xff17332c) : Color(0xffdcebe4);
Color get onSoft =>
    ParentTheme.dark.value ? Color(0xffb9efe0) : Color(0xff1c4238);
Color get accent => ParentTheme.dark.value ? Color(0xff8fd8c2) : green;
Color get onAccent => ParentTheme.dark.value ? Color(0xff06201a) : Colors.white;

class ParentTheme {
  static final dark = ValueNotifier(false);
  static Future<void> load() async {
    dark.value = await FamilyApi.storage.read(key: "darkMode") == "true";
  }

  static Future<void> set(bool value) async {
    dark.value = value;
    await FamilyApi.storage.write(key: "darkMode", value: "$value");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ParentTheme.load();
  try {
    await ZoneAlerts.initialize();
  } catch (_) {
    ZoneAlerts.status = 'Notifications need retry in Settings';
  }
  runApp(ParentApp());
}

String stamp(dynamic value) {
  final d = DateTime.tryParse(value?.toString() ?? '');
  return d == null
      ? 'Unknown'
      : DateFormat('d MMM, h:mm a').format(d.toLocal());
}

bool fresh(Map<String, dynamic>? d) {
  final fix = DateTime.tryParse(d?['fixAt']?.toString() ?? '');
  return d?['hasFix'] == true &&
      fix != null &&
      DateTime.now().difference(fix).inSeconds < 120 &&
      DateTime.now().difference(fix).inSeconds >= -5;
}

LatLng? point(Map<String, dynamic>? d) {
  if (d?['hasFix'] != true) return null;
  final a = d?['latitude'], b = d?['longitude'];
  if (a is! num ||
      b is! num ||
      !a.isFinite ||
      !b.isFinite ||
      a.abs() > 90 ||
      b.abs() > 180)
    return null;
  return LatLng(a.toDouble(), b.toDouble());
}

class ParentApp extends StatefulWidget {
  ParentApp({super.key});
  @override
  State<ParentApp> createState() => _ParentAppState();
}

class _ParentAppState extends State<ParentApp> {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: ParentTheme.dark,
    builder: (context, dark, _) => MaterialApp(
      title: 'Child Safety Parent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: accent,
              brightness: dark ? Brightness.dark : Brightness.light,
            ).copyWith(
              primary: accent,
              onPrimary: onAccent,
              surface: surface,
              onSurface: ink,
              outline: edge,
            ),
        scaffoldBackgroundColor: pale,
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titleTextStyle: TextStyle(
            color: ink,
            fontFamily: 'Space Grotesk',
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: TextStyle(color: muted, fontSize: 14, height: 1.45),
          insetPadding: EdgeInsets.all(20),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: ink,
            fontFamily: 'Space Grotesk',
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: edge),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: pale,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          labelStyle: TextStyle(fontSize: 13, color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: edge),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: edge),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accent, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
            minimumSize: Size.fromHeight(48),
            textStyle: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            shape: StadiumBorder(),
          ),
        ),
      ),
      home: FamilyHome(),
    ),
  );
}

Widget panel(List<Widget> children, {double radius = 24}) => Container(
  padding: EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: edge),
  ),
  child: Material(
    color: Colors.transparent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  ),
);
Widget label(String text) => Padding(
  padding: EdgeInsets.only(bottom: 7, top: 12),
  child: Text(
    text,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
  ),
);
Widget pill(String text, {Color? color}) => Container(
  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(
    color: (color ?? accent).withValues(alpha: .12),
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(
    text,
    style: TextStyle(
      fontSize: 12,
      color: color ?? accent,
      fontWeight: FontWeight.w600,
    ),
  ),
);
String ago(dynamic value) {
  final d = DateTime.tryParse(value?.toString() ?? '');
  if (d == null) return 'Unknown';
  final n = DateTime.now().difference(d).inSeconds;
  if (n < 0) return stamp(value);
  if (n < 60) return 'Just now';
  if (n < 3600) return '${n ~/ 60} min ago';
  if (n < 86400) return '${n ~/ 3600} hr ago';
  return stamp(value);
}

class FamilyHome extends StatefulWidget {
  FamilyHome({super.key});
  @override
  State<FamilyHome> createState() => _FamilyHomeState();
}

class _FamilyHomeState extends State<FamilyHome> {
  String childSearch = '';
  bool ready = false, signed = false, busy = false;
  String error = '';
  int section = 0;
  bool remember = true;
  final oldPass = TextEditingController(),
      newPass = TextEditingController(),
      confirmPass = TextEditingController();
  List<Map<String, dynamic>> children = [];
  final lastFixes = <String, Map<String, dynamic>>{};
  Timer? timer;
  final email = TextEditingController(),
      password = TextEditingController(),
      server = TextEditingController(),
      key = TextEditingController();
  @override
  void initState() {
    super.initState();
    ZoneAlerts.pendingDevice.addListener(openZoneNotification);
    _restore();
    // In-app self-update: check the update feed once after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybePromptUpdate(context);
    });
  }

  Future<void> openZoneNotification() async {
    final device = ZoneAlerts.pendingDevice.value;
    if (!signed || device == null || !mounted) return;
    final matches = children.where((c) => c['deviceId'] == device);
    if (matches.isEmpty) return;
    ZoneAlerts.pendingDevice.value = null;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildDetail(
          child: matches.first,
          initialTab: ZoneAlerts.pendingTab,
        ),
      ),
    );
  }

  Future<void> _restore() async {
    final ok = await FamilyApi.restore();
    if (!mounted) return;
    setState(() {
      ready = true;
      signed = ok;
      server.text = FamilyApi.server;
      key.text = FamilyApi.key;
    });
    if (ok) {
      await refresh();
      await ZoneAlerts.restoreSchedule();
      await openZoneNotification();
      await ParentPush.enable();
      timer = Timer.periodic(Duration(seconds: 30), (_) => refresh());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    ZoneAlerts.pendingDevice.removeListener(openZoneNotification);
    oldPass.dispose();
    newPass.dispose();
    confirmPass.dispose();
    email.dispose();
    password.dispose();
    server.dispose();
    key.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (busy || !signed) return;
    setState(() => busy = true);
    try {
      final list = await FamilyApi.request('/api/devices') as List;
      final data = await Future.wait(
        list.map((v) async {
          final d = Map<String, dynamic>.from(v);
          final id = Uri.encodeComponent(d['deviceId']);
          final latest = await FamilyApi.request('/api/location/latest/$id');
          Map<String, dynamic>? locationFix;
          if (latest is Map &&
              point(Map<String, dynamic>.from(latest)) != null) {
            locationFix = Map<String, dynamic>.from(latest);
            lastFixes[id] = locationFix;
          } else {
            locationFix = lastFixes[id];
            if (locationFix == null) {
              try {
                final history =
                    await FamilyApi.request('/api/location/history/$id')
                        as List? ??
                    [];
                final valid =
                    history
                        .whereType<Map>()
                        .map((h) => Map<String, dynamic>.from(h))
                        .where((h) => point(h) != null)
                        .toList()
                      ..sort(
                        (a, b) =>
                            (DateTime.tryParse(b['fixAt']?.toString() ?? '') ??
                                    DateTime(1900))
                                .compareTo(
                                  DateTime.tryParse(
                                        a['fixAt']?.toString() ?? '',
                                      ) ??
                                      DateTime(1900),
                                ),
                      );
                if (valid.isNotEmpty) {
                  locationFix = valid.first;
                  lastFixes[id] = locationFix;
                }
              } catch (_) {}
            }
          }

          final zones = await FamilyApi.request('/api/zones/$id');
          await ZoneAlerts.consume(d, (zones?['events'] as List?) ?? []);
          return {
            ...d,
            'latest': latest,
            'locationFix': locationFix,
            'zonesData': zones,
          };
        }),
      );
      try {
        await ZoneAlerts.pollSpeed();
      } catch (_) {}
      if (mounted)
        setState(() {
          children = data;
          error = '';
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Could not refresh. These are the last received reports, not live data.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> login() async {
    setState(() => busy = true);
    try {
      await FamilyApi.login(
        server.text,
        key.text,
        email.text,
        password.text,
        remember: remember,
      );
      password.clear();
      if (!mounted) return;
      setState(() {
        signed = true;
        busy = false;
        error = '';
      });
      await refresh();
      await ZoneAlerts.restoreSchedule();
      await openZoneNotification();
      await ParentPush.enable();
      timer?.cancel();
      timer = Timer.periodic(Duration(seconds: 30), (_) => refresh());
    } catch (e) {
      if (mounted)
        setState(() {
          busy = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
    }
  }

  Future<void> resetPassword() async {
    final reset = TextEditingController(text: email.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your parent email address to request a reset link.'),
            SizedBox(height: 12),
            TextField(
              controller: reset,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: 'Parent email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Send Reset Mail'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await FamilyApi.resetPassword(reset.text, key.text);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reset requested. Check your email.')),
          );
      } catch (e) {
        if (mounted)
          setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
    reset.dispose();
  }

  Future<void> changePassword() async {
    if (newPass.text.length < 8 ||
        newPass.text != confirmPass.text ||
        newPass.text == oldPass.text) {
      setState(
        () => error = 'Use a different password with at least 8 characters and matching confirmation.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      await FamilyApi.changePassword(oldPass.text, newPass.text);
      oldPass.clear();
      newPass.clear();
      confirmPass.clear();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Password updated.')));
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: signed,
    backgroundColor: pale,
    appBar: !signed
        ? null
        : SafetyHeader(
            title: section == 0 ? 'Your Family' : 'Settings',
            actions: [
              SafetyIconButton(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => setState(() => section = 1),
              ),
            ],
          ),
    bottomNavigationBar: !signed
        ? null
        : SafetyDock(
            index: section,
            onTap: (v) => setState(() => section = v),
            items: const [
              SafetyDockItem(Icons.phone_android_outlined, 'Children'),
              SafetyDockItem(Icons.settings_outlined, 'Settings'),
            ],
          ),
    body: !ready
        ? const Center(child: CircularProgressIndicator())
        : !signed
        ? loginView()
        : section == 1
        ? settingsView()
        : RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 116),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${children.length} protected devices connected',
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .7,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your Family',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafetyIconButton(
                      icon: Icons.refresh,
                      label: 'Refresh reports',
                      onTap: busy ? null : refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (busy) const LinearProgressIndicator(),
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(error, style: TextStyle(color: danger)),
                  ),
                if (children.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      onChanged: (v) => setState(() => childSearch = v),
                      decoration: InputDecoration(
                        hintText: 'Search children',
                        prefixIcon: Icon(Icons.search, color: muted, size: 20),
                        filled: true,
                        fillColor: tonal,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                if (children.isEmpty && !busy)
                  panel([
                    Text(
                      'No paired child phones yet',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pair each child phone with this account and start tracking.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ]),
                for (final child in children.where((c) {
                  final q = childSearch.trim().toLowerCase();
                  if (q.isEmpty) return true;
                  return '${c['name']}'.toLowerCase().contains(q) ||
                      '${c['deviceId']}'.toLowerCase().contains(q);
                }))
                  childCard(child),
                Text(
                  'Reports refresh while open. Push notifications are not connected yet. This app does not call emergency services.',
                  style: TextStyle(fontSize: 13, color: muted, height: 1.45),
                ),
              ],
            ),
          ),
  );
  Widget loginView() => SafeArea(
    child: LayoutBuilder(
      builder: (c, b) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: b.maxHeight),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(height: 32),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: soft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shield_outlined, color: onSoft, size: 34),
                ),
                SizedBox(height: 16),
                pill('CHILD SAFETY PARENT', color: accent),
                SizedBox(height: 12),
                Text(
                  'Parent Portal',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.98,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Your family monitoring companion',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                SizedBox(height: 40),
                darkField('EMAIL FIELD', email, Icons.email_outlined),
                SizedBox(height: 16),
                darkField(
                  'PASSWORD FIELD',
                  password,
                  Icons.lock_outline,
                  secret: true,
                ),
                Row(
                  children: [
                    Checkbox(
                      value: remember,
                      onChanged: (v) => setState(() => remember = v!),
                      side: BorderSide(color: muted),
                    ),
                    Text(
                      'Remember 30 days',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                    Spacer(),
                    TextButton(
                      onPressed: resetPassword,
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(color: accent, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: busy ? null : login,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        busy ? 'Signing in...' : 'Login',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(context).textTheme
                        .apply(bodyColor: muted),
                  ),
                  child: ExpansionTile(
                    iconColor: muted,
                    collapsedIconColor: muted,
                    title: Text(
                      'Server configuration',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    children: [
                      darkField(
                        'HTTPS SERVER ADDRESS',
                        server,
                        Icons.cloud_outlined,
                      ),
                      SizedBox(height: 12),
                      darkField(
                        'FIREBASE PUBLIC APP KEY',
                        key,
                        Icons.key_outlined,
                      ),
                    ],
                  ),
                ),
                if (error.isNotEmpty)
                  Text(error, style: TextStyle(color: Colors.redAccent)),
                SizedBox(height: 32),
                Text(
                  'Firebase sign-in - Password is not saved',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget darkField(
    String title,
    TextEditingController controller,
    IconData icon, {
    bool secret = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          color: muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
        ),
      ),
      SizedBox(height: 7),
      TextField(
        controller: controller,
        obscureText: secret,
        keyboardType: secret
            ? TextInputType.visiblePassword
            : TextInputType.text,
        style: TextStyle(color: ink, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: muted, size: 18),
        ),
      ),
    ],
  );
  Future<void> passwordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text('Change password'),
          contentPadding: EdgeInsets.fromLTRB(24, 12, 24, 4),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label('Old Password'),
                  TextField(
                    controller: oldPass,
                    obscureText: true,
                    decoration: InputDecoration(hintText: 'Current password'),
                  ),
                  label('New Password'),
                  TextField(
                    controller: newPass,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'At least 8 characters',
                    ),
                  ),
                  label('Confirm New Password'),
                  TextField(
                    controller: confirmPass,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Re-enter new password',
                    ),
                  ),
                  SizedBox(height: 14),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            update(() => busy = true);
                            await changePassword();
                            if (c.mounted) update(() => busy = false);
                          },
                    child: Text(busy ? 'Updating...' : 'Update Password'),
                  ),
                  if (error.isNotEmpty)
                    Text(error, style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text('Close')),
          ],
        ),
      ),
    );
    oldPass.clear();
    newPass.clear();
    confirmPass.clear();
  }

  Widget settingsView() => ListView(
    padding: EdgeInsets.fromLTRB(16, 4, 16, 116),
    children: [
      panel([
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.person, color: green),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FamilyApi.email.isEmpty
                        ? 'Parent account'
                        : FamilyApi.email,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Signed in with Firebase Authentication. Remembered login required in the background.',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ]),
      SizedBox(height: 16),
      panel([
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.system_update_alt, color: green),
          title: Text(
            'Check for updates',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text('Get the latest Child Safety Parent release'),
          onTap: () => checkUpdateManually(context),
        ),
      ]),
      SizedBox(height: 16),
      panel([
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "Dark mode",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text("Saved on this phone"),
          secondary: Icon(Icons.dark_mode_outlined, color: green),
          value: ParentTheme.dark.value,
          onChanged: (v) => ParentTheme.set(v),
        ),
      ]),
      SizedBox(height: 16),
      panel([
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text('Safe-zone notifications'),
          subtitle: Text(ZoneAlerts.status),
          value: ZoneAlerts.enabled,
          onChanged: ZoneAlerts.changing
              ? null
              : (v) async {
                  setState(() {
                    ZoneAlerts.changing = true;
                    ZoneAlerts.status = v ? 'Turning on...' : 'Turning off...';
                  });
                  final progress = Timer.periodic(
                    const Duration(milliseconds: 400),
                    (_) {
                      if (mounted) setState(() {});
                    },
                  );
                  try {
                    if (v) {
                      await ZoneAlerts.enable(children);
                    } else {
                      await ZoneAlerts.disable();
                    }
                  } catch (_) {
                    ZoneAlerts.status = 'Could not save notification settings. Restart and retry.';
                  } finally {
                    progress.cancel();
                    ZoneAlerts.changing = false;
                    if (mounted) setState(() {});
                  }
                },
        ),
        if (ZoneAlerts.changing)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        if (ZoneAlerts.status.contains('blocked'))
          Text(
            'Open Android Settings > Apps > Child Safety Parent > Notifications and allow notifications.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
        Text(
          'Alerts on entry and exit. While open: checks every 30 seconds. Background: Android schedules checks from 15 minutes; battery limits, no internet or force-stop can delay or stop alerts. Not instant push. Remembered login required in background.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
      ]),
      SizedBox(height: 16),
      panel([
        Text(
          'PUSH ALERTS',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 8),
        Text(ParentPush.status, style: TextStyle(fontSize: 13, color: muted)),
        SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            await ZoneAlerts.restoreSchedule();
            await openZoneNotification();
            await ParentPush.enable();
            if (mounted) setState(() {});
          },
          icon: Icon(Icons.notifications_outlined, size: 16),
          label: Text('Enable notifications'),
        ),
        SizedBox(height: 8),
        TextButton(
          onPressed: () async {
            try {
              await ParentPush.disable();
              if (mounted) setState(() {});
            } catch (_) {
              if (mounted)
                setState(
                  () => error = 'Could not disable registration. Try again.',
                );
            }
          },
          child: Text('Disable notifications'),
        ),
        Text(
          'SOS, zone crossings, low battery and speed. Delivery depends on network, Android permissions and server availability.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
      ]),
      SizedBox(height: 16),
      panel([
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline, color: green),
          title: Text(
            'Change Password',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          trailing: Icon(Icons.chevron_right),
          onTap: passwordDialog,
        ),
      ]),
      SizedBox(height: 16),
      panel([
        Text(
          'SESSION',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        Divider(),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: danger),
          onPressed: () async {
            try {
              await ParentPush.disable();
              await ZoneAlerts.disableAll();
              await FamilyApi.logout();
            } catch (_) {
              if (mounted)
                setState(
                  () => error = 'Could not finish logout. You are still signed in; automatic refresh remains on. Retry when connected.',
                );
              return;
            }
            timer?.cancel();
            if (mounted)
              setState(() {
                signed = false;
                children = [];
                lastFixes.clear();
                section = 0;
              });
          },
          icon: Icon(Icons.logout, size: 16),
          label: Text('Logout'),
        ),
      ]),
      panel([
        Text('App version', style: TextStyle(color: muted, fontSize: 13)),
        SizedBox(height: 4),
        Text(
          'v$appVersion',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
      Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Reports refresh while open. Push notifications are not connected yet. This app does not call emergency services.',
          style: TextStyle(fontSize: 13, color: muted),
        ),
      ),
    ],
  );
  Future<void> removeChild(Map<String, dynamic> child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Remove ${child['childName'] ?? 'child'}?'),
        content: Text(
          'Device: ${child['deviceId']}\n\nThis child will stop showing in your dashboard and new reports to this parent will stop. Stored history is kept. The child app is not wiped. Pair again with this parent to resume.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text('Remove device'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final capabilities = await FamilyApi.request('/api/devices/capabilities');
      if (capabilities['historyPreservingUnlink'] != true)
        throw Exception('Server needs safe unlink update');
      final result = await FamilyApi.request(
        '/api/devices/${Uri.encodeComponent(child['deviceId'])}',
        method: 'DELETE',
      );
      if (result['status'] != 'unlinked')
        throw Exception('Server needs update');
      await ZoneAlerts.configureSpeed(child['deviceId'], 0);
      lastFixes.remove(Uri.encodeComponent(child['deviceId']));
      if (mounted) {
        setState(
          () => children.removeWhere((c) => c['deviceId'] == child['deviceId']),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device removed. Stored history kept.')),
        );
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not confirm removal. Refresh and check the device before retrying.',
            ),
          ),
        );
    }
  }

  Widget childCard(Map<String, dynamic> child) {
    final latest = child['latest'] as Map<String, dynamic>?;
    final location = child['locationFix'] as Map<String, dynamic>? ?? latest;
    final p = point(location);
    final events = child['zonesData']?['events'] as List? ?? [];
    final live = fresh(latest) && error.isEmpty;
    final name = child['childName']?.toString() ?? 'Child';
    final sos = latest?['emergency'] == true;
    Widget stat(String title, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: tonal,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          panel([
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChildDetail(child: child)),
                );
                await refresh();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: soft,
                        foregroundColor: onSoft,
                        child: Text(
                          name.isEmpty ? '?' : name[0].toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                color: ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Android • ${child['deviceId']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: muted),
                            ),
                            const SizedBox(height: 5),
                            pill(
                              live ? 'Live' : 'Last known',
                              color: live ? accent : onAmber,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 96,
                      child: Stack(
                        children: [
                          if (p != null)
                            MiniMap(points: [p], fresh: live)
                          else
                            Container(
                              color: tonal,
                              child: Center(
                                child: Text(
                                  'Location unavailable',
                                  style: TextStyle(color: muted),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            right: 8,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${location?['city'] ?? 'Unknown location'}${location?['accuracy'] != null ? ' • ±${location!['accuracy']}m' : ''}',
                                  maxLines: 2,
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      stat('BATTERY', '${latest?['battery'] ?? '--'}%'),
                      const SizedBox(width: 8),
                      stat('LAST REPORT', ago(latest?['receivedAt'])),
                      const SizedBox(width: 8),
                      stat(
                        'STATUS',
                        live
                            ? 'Live'
                            : p == null
                            ? 'No GPS fix'
                            : 'Stale',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: events.isEmpty ? tonal : amber,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      events.isEmpty
                          ? 'No zone alerts yet'
                          : 'Zone Alert: ${events.first['entered'] == true ? 'Entered' : 'Left'} ${events.first['zoneName']} • ${stamp(events.first['fixAt'])}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: events.isEmpty ? muted : onAmber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    live
                        ? 'Updated while the dashboard is open.'
                        : p == null
                        ? 'No GPS fix reported yet.'
                        : 'Last known location • ${stamp(location?['fixAt'])}',
                    style: TextStyle(fontSize: 13, height: 1.45, color: muted),
                  ),
                ),
                TextButton(
                  onPressed: () => removeChild(child),
                  style: TextButton.styleFrom(foregroundColor: danger),
                  child: const Text(
                    'Remove device',
                    style: TextStyle(
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ]),
          if (sos)
            Positioned(
              top: -9,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: danger,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'SOS ACTIVE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: pale,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MiniMap extends StatelessWidget {
  final List<LatLng> points;
  final List<dynamic> zones;
  final bool fresh;
  MiniMap({
    super.key,
    required this.points,
    this.fresh = false,
    this.zones = const [],
  });
  @override
  Widget build(BuildContext context) => FlutterMap(
    options: MapOptions(
      initialCenter: points.isEmpty ? LatLng(20.59, 78.96) : points.last,
      initialZoom: points.isEmpty ? 4 : 14,
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.childsafety.parent',
      ),
      if (zones.isNotEmpty)
        CircleLayer(
          circles: [
            for (final z in zones)
              if (z['latitude'] is num && z['longitude'] is num)
                CircleMarker(
                  point: LatLng(
                    (z['latitude'] as num).toDouble(),
                    (z['longitude'] as num).toDouble(),
                  ),
                  radius: (z['radius'] as num).toDouble(),
                  useRadiusInMeter: true,
                  color: green.withValues(alpha: .15),
                  borderColor: green,
                  borderStrokeWidth: 2,
                ),
          ],
        ),
      if (points.length > 1)
        PolylineLayer(
          polylines: [Polyline(points: points, color: green, strokeWidth: 4)],
        ),
      if (points.isNotEmpty)
        MarkerLayer(
          markers: [
            Marker(
              point: points.last,
              child: Icon(
                Icons.location_on,
                color: fresh ? green : Colors.grey,
                size: 38,
              ),
            ),
          ],
        ),
      SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
    ],
  );
}

class ChildDetail extends StatefulWidget {
  final Map<String, dynamic> child;
  final int initialTab;
  ChildDetail({super.key, required this.child, this.initialTab = 0});
  @override
  State<ChildDetail> createState() => _ChildDetailState();
}

class _ChildDetailState extends State<ChildDetail> with WidgetsBindingObserver {
  Timer? refreshTimer;
  Timer? freshnessTimer;
  int generation = 0;
  int activeLoads = 0;
  Map<String, dynamic>? latestReport;
  Map<String, dynamic>? lastFix;
  List<dynamic> history = [];
  List<dynamic> speedAlerts = [];
  String error = '';
  bool busy = true;
  int interval = 30;
  int batteryThreshold = 0, speedLimit = 0;
  Map<String, dynamic> zones = {};
  Timer? playback;
  int playIndex = 0;
  bool playing = false;
  String get id => Uri.encodeComponent(widget.child['deviceId']);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    latestReport = widget.child['latest'] as Map<String, dynamic>?;
    lastFix = newestDeviceFix(widget.child['deviceId'], [
      latestReport,
      widget.child['locationFix'],
    ]);
    resumeRefresh();
    interval = widget.child['reportIntervalSeconds'] ?? 30;
    batteryThreshold = widget.child['lowBatteryThreshold'] ?? 0;
    speedLimit = widget.child['speedLimitKph'] ?? 0;
    load();
  }

  @override
  void dispose() {
    generation++;
    refreshTimer?.cancel();
    freshnessTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    playback?.cancel();
    super.dispose();
  }

  void resumeRefresh() {
    refreshTimer?.cancel();
    freshnessTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (activeLoads == 0) load();
    });
    freshnessTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resumeRefresh();
      load();
    } else {
      generation++; // Ignore responses started before the app was paused.
      refreshTimer?.cancel();
      freshnessTimer?.cancel();
    }
  }

  @override
  void didUpdateWidget(covariant ChildDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child['deviceId'] != widget.child['deviceId']) {
      generation++;
      history = [];
      speedAlerts = [];
      zones = {};
      latestReport = widget.child['latest'] as Map<String, dynamic>?;
      lastFix = newestDeviceFix(widget.child['deviceId'], [
        latestReport,
        widget.child['locationFix'],
      ]);
      busy = true;
      load();
    }
  }

  Future<void> load() async {
    final request = ++generation;
    final deviceId = widget.child['deviceId'] as String;
    final path = Uri.encodeComponent(deviceId);
    activeLoads++;
    try {
      final results = [
        await FamilyApi.request('/api/location/latest/$path'),
        await FamilyApi.request('/api/location/history/$path'),
        await FamilyApi.request('/api/zones/$path'),
      ];
      List<dynamic> alerts = [];
      try {
        final response = await FamilyApi.request('/api/alerts');
        alerts = (response['alerts'] as List? ?? [])
            .where((a) => a['deviceId'] == deviceId && a['type'] == 'speed')
            .toList();
      } catch (_) {}
      if (!mounted ||
          request != generation ||
          deviceId != widget.child['deviceId'])
        return;
      setState(() {
        latestReport = results[0] == null
            ? null
            : Map<String, dynamic>.from(results[0] as Map);
        history = (results[1] as List? ?? [])
            .where((h) => h is Map && h['deviceId'] == deviceId)
            .toList();
        lastFix = newestDeviceFix(deviceId, [
          lastFix,
          latestReport,
          ...history,
        ]);
        zones = Map<String, dynamic>.from(results[2] as Map? ?? {});
        speedAlerts = alerts;
        busy = false;
        error = '';
        if (playing) {
          playback?.cancel();
          playing = false;
        }
      });
    } catch (_) {
      if (mounted && request == generation)
        setState(() {
          busy = false;
          error = 'Could not refresh this child. Showing last received data.';
        });
    } finally {
      activeLoads--;
    }
  }

  Future<void> saveAlerts() async {
    try {
      await FamilyApi.request(
        '/api/alerts/$id/settings',
        method: 'PUT',
        data: {
          'lowBatteryThreshold': batteryThreshold,
          'speedLimitKph': speedLimit,
        },
      );
      final ready = await ZoneAlerts.configureSpeed(
        widget.child['deviceId'],
        speedLimit,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ready
                  ? 'Alert settings saved. Speed notifications enabled when speed alert is on.'
                  : 'Threshold saved, but Android notifications are blocked. Allow them in app Settings and save again.',
            ),
          ),
        );
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save alert settings.');
    }
  }

  Future<void> saveInterval() async {
    try {
      await FamilyApi.request(
        '/api/devices/$id/interval',
        method: 'PUT',
        data: {'seconds': interval},
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved. Applies on the next successful report.'),
          ),
        );
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save interval.');
    }
  }

  Future<void> addZone([dynamic existing]) async {
    final name = TextEditingController(text: existing?['name'] ?? '');
    final radius = TextEditingController(text: '${existing?['radius'] ?? 300}');
    String? formError;
    LatLng? selected = existing == null
        ? point(widget.child['locationFix'] ?? widget.child['latest'])
        : LatLng(
            (existing['latitude'] as num).toDouble(),
            (existing['longitude'] as num).toDouble(),
          );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(existing == null ? 'Add safe zone' : 'Edit safe zone'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tap the map to choose the centre.'),
                  SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ClipRect(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: selected ?? LatLng(20.59, 78.96),
                          initialZoom: selected == null ? 4 : 14,
                          onTap: (_, p) => setDialog(() => selected = p),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.childsafety.parent',
                          ),
                          if (selected != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: selected!,
                                  child: Icon(Icons.location_on, color: green),
                                ),
                              ],
                            ),
                          SimpleAttributionWidget(
                            source: Text(
                              'OpenStreetMap contributors',
                              style: TextStyle(fontSize: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: name,
                    maxLength: 60,
                    decoration: InputDecoration(labelText: 'Zone name'),
                  ),
                  TextField(
                    controller: radius,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Radius: 100-10,000 metres',
                    ),
                  ),
                  if (formError != null)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        formError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final metres = int.tryParse(radius.text);
                if (name.text.trim().isEmpty ||
                    metres == null ||
                    metres < 100 ||
                    metres > 10000 ||
                    selected == null) {
                  setDialog(
                    () => formError = 'Choose a centre, a name, and radius from 100 to 10,000 metres.',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text('Save zone'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && selected != null) {
      final metres = int.tryParse(radius.text);
      if (name.text.trim().isEmpty ||
          metres == null ||
          metres < 100 ||
          metres > 10000) {
        if (mounted)
          setState(
            () => error =
                'Enter a name and radius between 100 and 10,000 metres.',
          );
      } else {
        try {
          await FamilyApi.request(
            existing == null
                ? '/api/zones/$id'
                : '/api/zones/$id/${existing['id']}',
            method: existing == null ? 'POST' : 'PUT',
            data: {
              'name': name.text.trim(),
              'latitude': selected!.latitude,
              'longitude': selected!.longitude,
              'radius': metres,
            },
          );
          await load();
        } catch (_) {
          if (mounted)
            setState(
              () => error =
                  'Could not save zone. Check connection and zone details.',
            );
        }
      }
    }
    name.dispose();
    radius.dispose();
  }

  Future<void> deleteZone(dynamic z) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete ${z['name']}?'),
        content: Text('This also removes its enter/exit alerts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await FamilyApi.request('/api/zones/$id/${z['id']}', method: 'DELETE');
        await load();
      } catch (_) {
        if (mounted) setState(() => error = 'Could not delete zone.');
      }
    }
  }

  void togglePlayback(int count) {
    if (playing) {
      playback?.cancel();
      setState(() => playing = false);
      return;
    }
    setState(() {
      playing = true;
      playIndex = 0;
    });
    playback = Timer.periodic(Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      if (playIndex >= count - 1) {
        playback?.cancel();
        setState(() => playing = false);
      } else {
        setState(() => playIndex++);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordered = history.reversed
        .map((x) => Map<String, dynamic>.from(x))
        .where((x) => point(x) != null)
        .toList();
    final latest = latestReport;
    final location = newestDeviceFix(widget.child['deviceId'], [
      lastFix,
      latest,
      ...history,
    ]);
    final current = point(location);
    final pts = ordered.map((x) => point(x)!).toList();
    final shown = playing && pts.isNotEmpty
        ? pts.take(playIndex + 1).toList()
        : current != null
        ? [current]
        : <LatLng>[];
    final safe = zones['zones'] as List? ?? [];
    final sos = history.where((x) => x['emergency'] == true).toList();
    final live = fresh(location) && error.isEmpty;
    final name = widget.child['childName'] ?? 'Child';
    return DefaultTabController(
      length: 5,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: pale,
        appBar: SafetyDetailHeader(
          name: name.toString(),
          subtitle: live
              ? 'Recent GPS fix • ${stamp(location?['fixAt'])} • ${location?['city'] ?? 'Location unavailable'}'
              : 'Last GPS fix: ${stamp(location?['fixAt'])}',
          labels: [
            'Map & History',
            'Safe zones (${safe.length})',
            'SOS alerts',
            'Sync interval',
            'Phone activity',
          ],
        ),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (error.isNotEmpty)
                        Text(error, style: TextStyle(color: danger)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: SizedBox(
                          height: 190,
                          child: Stack(
                            children: [
                              MiniMap(
                                key: ValueKey(
                                  'route-$playing-$playIndex-${playing ? '' : current}',
                                ),
                                points: shown,
                                fresh: !playing && live,
                                zones: safe,
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                right: 12,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: pill(
                                    '$name • ${playing ? 'Recorded route' : location?['city'] ?? 'Location unavailable'}',
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${safe.length} safe zones • ${latest?['accuracy'] != null ? 'GPS ±${latest!['accuracy']}m' : 'GPS accuracy unavailable'}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: muted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: pts.isEmpty
                                ? null
                                : () => togglePlayback(pts.length),
                            icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                            label: Text(
                              playing ? 'Stop' : 'Play route history',
                            ),
                          ),
                          Text(
                            'Historical GPS • gaps may be missing',
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                      Slider(
                        value: pts.isEmpty
                            ? 0
                            : playIndex.clamp(0, pts.length - 1).toDouble(),
                        max: pts.length <= 1 ? 1 : pts.length - 1.0,
                        onChanged: pts.isEmpty
                            ? null
                            : (v) {
                                playback?.cancel();
                                setState(() {
                                  playing = true;
                                  playIndex = v.toInt();
                                });
                              },
                      ),
                      Text(
                        ordered.isEmpty
                            ? 'No history'
                            : 'Historical GPS • ${stamp(ordered[playIndex.clamp(0, ordered.length - 1)]['fixAt'])}',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                      const SizedBox(height: 14),
                      panel([
                        draftTitle('Recent history'),
                        const SizedBox(height: 10),
                        if (todayHistory(ordered).isEmpty)
                          Text(
                            'No history today',
                            style: TextStyle(color: muted),
                          ),
                        for (final h in todayHistory(ordered))
                          draftHistoryRow(
                            stamp(h['fixAt']),
                            h['city']?.toString() ?? 'Recorded location',
                            '${h['accuracy'] != null ? '±${h['accuracy']} m' : 'Accuracy unavailable'} • ${h['battery'] ?? '--'}% battery',
                          ),
                      ]),
                      const SizedBox(height: 14),
                      Text(
                        'Route playback joins recorded points and may have gaps. Old reports are not live GPS.',
                        style: TextStyle(
                          fontSize: 13,
                          color: muted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      FilledButton.icon(
                        onPressed: addZone,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Zone'),
                      ),
                      const SizedBox(height: 14),
                      if (safe.isEmpty)
                        panel([draftTitle('No safe zones yet')]),
                      for (final z in safe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: panel([
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      draftTitle(z['name'].toString()),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Radius ${z['radius']} m',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                pill(
                                  z['inside'] == null
                                      ? 'Waiting'
                                      : z['inside'] == true
                                      ? 'Inside'
                                      : 'Outside',
                                  color: z['inside'] == true ? accent : onAmber,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Entry and exit alerts',
                                  style: TextStyle(fontSize: 13, color: muted),
                                ),
                                TextButton(
                                  onPressed: () => addZone(z),
                                  child: const Text('Edit'),
                                ),
                                TextButton(
                                  onPressed: () => deleteZone(z),
                                  style: TextButton.styleFrom(
                                    foregroundColor: danger,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ]),
                        ),
                      panel([
                        draftTitle('Recent zone alerts'),
                        for (final e in zones['events'] as List? ?? [])
                          draftHistoryRow(
                            stamp(e['fixAt']),
                            '${e['entered'] == true ? 'Entered' : 'Left'} ${e['zoneName']}',
                            'Recorded zone event',
                          ),
                      ]),
                      const SizedBox(height: 14),
                      Text(
                        'Alerts need two fresh reports. Up to 10 zones per device.',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (sos.isEmpty)
                        panel([
                          draftTitle('Emergency SOS history'),
                          const SizedBox(height: 10),
                          Text(
                            'No SOS reports received',
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ]),
                      for (final h in sos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: panel([
                            Text(
                              'EMERGENCY SOS HISTORY',
                              style: TextStyle(
                                fontSize: 11,
                                color: muted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            draftTitle(
                              'SOS Button Pressed, ${stamp(h['receivedAt'])}',
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '$name reported an emergency from ${h['city'] ?? 'an unknown location'}.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: muted,
                              ),
                            ),
                          ]),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        'Recorded device alerts. No emergency calls or acknowledgement workflow.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      panel([
                        draftTitle('Report interval'),
                        label('Location reports'),
                        DropdownButtonFormField<int>(
                          initialValue: interval,
                          items: [
                            for (final v in [30, 60, 120, 300, 600, 1800, 3600])
                              DropdownMenuItem(
                                value: v,
                                child: Text(
                                  v == 30
                                      ? 'Every 30 seconds'
                                      : v == 3600
                                      ? 'Every 1 hour'
                                      : 'Every ${v ~/ 60} ${v == 60 ? 'minute' : 'minutes'}',
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => interval = v!),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: saveInterval,
                          child: const Text('Save Interval Setting'),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "Controls how often $name's phone sends reports. Applies on its next successful report. Long intervals can miss short zone visits. GPS may remain active, so battery savings are not guaranteed.",
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: muted,
                          ),
                        ),
                        if (error.isNotEmpty)
                          Text(error, style: TextStyle(color: danger)),
                      ]),
                      const SizedBox(height: 14),
                      panel([
                        draftTitle('Safety alerts'),
                        label('Low battery threshold'),
                        DropdownButtonFormField<int>(
                          initialValue: batteryThreshold,
                          items: [
                            for (final v in [0, 10, 15, 20, 30])
                              DropdownMenuItem(
                                value: v,
                                child: Text(v == 0 ? 'Off' : '$v%'),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => batteryThreshold = v!),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Speed alert'),
                          value: speedLimit > 0,
                          onChanged: (v) =>
                              setState(() => speedLimit = v ? 80 : 0),
                        ),
                        if (speedLimit > 0)
                          Column(
                            children: [
                              Text('Alert above $speedLimit km/h'),
                              Slider(
                                min: 10,
                                max: 200,
                                divisions: 38,
                                value: speedLimit.toDouble(),
                                onChanged: (v) =>
                                    setState(() => speedLimit = v.round()),
                              ),
                            ],
                          ),
                        for (final a in speedAlerts.take(5))
                          draftHistoryRow(
                            stamp(a['reportedAt']),
                            a['title']?.toString() ?? 'Speed alert',
                            '${a['body']}',
                          ),
                        if (speedAlerts.isEmpty)
                          Text(
                            'No recorded speed alerts yet.',
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: saveAlerts,
                          child: const Text('Save Alert Settings'),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tap Save Alert Settings to apply. Requires two fresh accurate GPS speed reports. Open-app checks every 30 seconds; background checks 15 minutes or later. Not instant push. GPS is an estimate.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: muted,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      panel([
                        draftTitle('Offline reports'),
                        const SizedBox(height: 8),
                        Text(
                          'Updated child app stores up to 2,880 encrypted reports while offline, then uploads them in order when the connection returns. Original GPS times stay unchanged. Old reports are not live location; tracking stops if Android force-stops the app.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: muted,
                          ),
                        ),
                      ]),
                    ],
                  ),
                  ActivityTab(deviceId: widget.child['deviceId']),
                ],
              ),
      ),
    );
  }
}
