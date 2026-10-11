import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'api.dart';
import 'push.dart';

const green = Color(0xff16a34a);
const ink = Color(0xff0f172a);
const muted = Color(0xff64748b);
const pale = Color(0xfff1f5f9);
void main() {
  runApp(const ParentApp());
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
  const ParentApp({super.key});
  @override
  State<ParentApp> createState() => _ParentAppState();
}

class _ParentAppState extends State<ParentApp> {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Child Safety Parent',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: pale,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xfff8fafc),
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffe2e8f0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffe2e8f0)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home: const FamilyHome(),
  );
}

Widget panel(List<Widget> children, {double radius = 18}) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xffe2e8f0)),
    boxShadow: const [
      BoxShadow(color: Color(0x09000000), blurRadius: 3, offset: Offset(0, 2)),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  ),
);
Widget label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 7, top: 12),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: muted,
    ),
  ),
);
Widget pill(String text, {Color color = green}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .1),
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(
    text,
    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
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
  const FamilyHome({super.key});
  @override
  State<FamilyHome> createState() => _FamilyHomeState();
}

class _FamilyHomeState extends State<FamilyHome> {
  bool ready = false, signed = false, busy = false;
  String error = '';
  int section = 0;
  bool remember = true;
  final oldPass = TextEditingController(),
      newPass = TextEditingController(),
      confirmPass = TextEditingController();
  List<Map<String, dynamic>> children = [];
  Timer? timer;
  final email = TextEditingController(),
      password = TextEditingController(),
      server = TextEditingController(),
      key = TextEditingController();
  @override
  void initState() {
    super.initState();
    _restore();
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
      await ParentPush.enable();
      timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
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
          final zones = await FamilyApi.request('/api/zones/$id');
          return {...d, 'latest': latest, 'zonesData': zones};
        }),
      );
      if (mounted)
        setState(() {
          children = data;
          error = '';
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'Could not refresh. These are the last received reports, not live data.',
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
      await ParentPush.enable();
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
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
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your parent email address to request a reset link.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reset,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Parent email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Send Reset Mail'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await FamilyApi.resetPassword(reset.text, key.text);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reset requested. Check your email.')),
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
        () => error =
            'Use a different password with at least 8 characters and matching confirmation.',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password updated.')));
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: signed ? pale : ink,
    appBar: !signed
        ? null
        : AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section == 0 ? 'Your Family' : 'Parent Account Settings',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (section == 0)
                  Text(
                    '${children.length} protected devices connected',
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
              ],
            ),
            actions: section == 0
                ? [
                    IconButton(
                      tooltip: 'Refresh reports',
                      onPressed: busy ? null : refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => setState(() => section = 1),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ]
                : null,
          ),
    bottomNavigationBar: !signed
        ? null
        : BottomNavigationBar(
            backgroundColor: Colors.white,
            selectedItemColor: green,
            unselectedItemColor: const Color(0xff94a3b8),
            currentIndex: section,
            onTap: (v) => setState(() => section = v),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.family_restroom),
                label: 'Children',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
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
              padding: const EdgeInsets.all(16),
              children: [
                if (busy) const LinearProgressIndicator(),
                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.red)),
                if (children.isEmpty && !busy)
                  panel([
                    const Text('No paired child phones yet'),
                    const SizedBox(height: 8),
                    const Text(
                      'Pair each child phone with this account and start tracking.',
                      style: TextStyle(color: muted),
                    ),
                  ]),
                for (final child in children) childCard(child),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Reports refresh while open. Push notifications are not connected yet. This app does not call emergency services.',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [green, Color(0xff22c55e)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Color(0x4022c55e), blurRadius: 30),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                pill('CHILD SAFETY PARENT', color: const Color(0xff34d399)),
                const SizedBox(height: 12),
                const Text(
                  'Parent Portal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your family monitoring companion',
                  style: TextStyle(color: Color(0xff94a3b8), fontSize: 12),
                ),
                const SizedBox(height: 56),
                darkField('EMAIL FIELD', email, Icons.email_outlined),
                const SizedBox(height: 18),
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
                      side: const BorderSide(color: muted),
                    ),
                    const Text(
                      'Remember 30 days',
                      style: TextStyle(color: Color(0xff94a3b8), fontSize: 11),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: resetPassword,
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: Color(0xff34d399),
                          fontSize: 11,
                        ),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    textTheme: Theme.of(
                      context,
                    ).textTheme.apply(bodyColor: const Color(0xff94a3b8)),
                  ),
                  child: ExpansionTile(
                    iconColor: muted,
                    collapsedIconColor: muted,
                    title: const Text(
                      'Server configuration',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    children: [
                      darkField(
                        'HTTPS SERVER ADDRESS',
                        server,
                        Icons.cloud_outlined,
                      ),
                      const SizedBox(height: 12),
                      darkField(
                        'FIREBASE PUBLIC APP KEY',
                        key,
                        Icons.key_outlined,
                      ),
                    ],
                  ),
                ),
                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 40),
                const Text(
                  'Firebase sign-in • Password is not saved',
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
        style: const TextStyle(
          color: Color(0xff94a3b8),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .5,
        ),
      ),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        obscureText: secret,
        keyboardType: secret
            ? TextInputType.visiblePassword
            : TextInputType.text,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          fillColor: const Color(0xff1e293b),
          prefixIcon: Icon(icon, color: muted, size: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xff334155)),
          ),
        ),
      ),
    ],
  );
  Future<void> passwordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          contentPadding: const EdgeInsets.all(12),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: panel([
                const Text(
                  'CHANGE PASSWORD',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const Divider(),
                label('Old Password'),
                TextField(
                  controller: oldPass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Current password',
                  ),
                ),
                label('New Password'),
                TextField(
                  controller: newPass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'At least 8 characters',
                  ),
                ),
                label('Confirm New Password'),
                TextField(
                  controller: confirmPass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Re-enter new password',
                  ),
                ),
                const SizedBox(height: 14),
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
                  Text(error, style: const TextStyle(color: Colors.red)),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    oldPass.clear();
    newPass.clear();
    confirmPass.clear();
  }

  Widget settingsView() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      panel([
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xffdcfce7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person, color: green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FamilyApi.email.isEmpty
                        ? 'Parent account'
                        : FamilyApi.email,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'Firebase Authentication',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ]),
      const SizedBox(height: 16),
      panel([
        const Text(
          'PUSH ALERTS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          ParentPush.status,
          style: const TextStyle(fontSize: 11, color: muted),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            await ParentPush.enable();
            if (mounted) setState(() {});
          },
          icon: const Icon(Icons.notifications_outlined, size: 16),
          label: const Text('Enable notifications'),
        ),
        const SizedBox(height: 8),
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
          child: const Text('Disable notifications'),
        ),
        const Text(
          'SOS, zone crossings, low battery and speed. Delivery depends on network, Android permissions and server availability.',
          style: TextStyle(fontSize: 10, color: muted),
        ),
      ]),
      const SizedBox(height: 16),
      panel([
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline, color: green),
          title: const Text(
            'Change Password',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: passwordDialog,
        ),
      ]),
      const SizedBox(height: 16),
      panel([
        const Text(
          'SESSION',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        const Divider(),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xffdc2626),
          ),
          onPressed: () async {
            timer?.cancel();
            try {
              await ParentPush.disable();
            } catch (_) {
              if (mounted)
                setState(
                  () => error =
                      'Could not remove push registration. Try logout again when connected.',
                );
              return;
            }
            await FamilyApi.logout();
            if (mounted)
              setState(() {
                signed = false;
                children = [];
                section = 0;
              });
          },
          icon: const Icon(Icons.logout, size: 16),
          label: const Text('Logout'),
        ),
      ]),
    ],
  );
  Widget childCard(Map<String, dynamic> child) {
    final latest = child['latest'] as Map<String, dynamic>?;
    final p = point(latest);
    final events = child['zonesData']?['events'] as List? ?? [];
    final live = fresh(latest) && error.isEmpty;
    final name = child['childName']?.toString() ?? 'Child';
    final sos = latest?['emergency'] == true;
    Widget stat(String a, String b, {bool accent = false}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: accent ? const Color(0xfff0fdf4) : const Color(0xfff8fafc),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: accent ? const Color(0xffdcfce7) : pale),
        ),
        child: Column(
          children: [
            Text(
              a,
              style: TextStyle(
                fontSize: 9,
                color: accent ? green : const Color(0xff94a3b8),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              b,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent ? green : ink,
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChildDetail(child: child)),
          );
          await refresh();
        },
        child: Stack(
          children: [
            panel([
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            pill(
                              live ? 'Live' : 'Last Known',
                              color: live ? green : muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Android • ${child['deviceId']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 120,
                  child: Stack(
                    children: [
                      if (p != null)
                        MiniMap(points: [p], fresh: live)
                      else
                        const Center(
                          child: Text(
                            'Location unavailable',
                            style: TextStyle(color: muted),
                          ),
                        ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: .8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${latest?['city'] ?? 'Unknown location'}${latest?['accuracy'] != null ? ' • ±${latest!['accuracy']}m' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  stat('BATTERY', '${latest?['battery'] ?? '--'}%'),
                  stat('LAST REPORT', ago(latest?['receivedAt'])),
                  stat(
                    'STATUS',
                    live ? 'Live GPS' : 'Last known',
                    accent: live,
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: events.isEmpty
                      ? const Color(0xfff8fafc)
                      : const Color(0xfffffbeb),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  events.isEmpty
                      ? 'No zone alerts yet'
                      : 'Zone Alert: ${events.first['entered'] == true ? 'Entered' : 'Left'} ${events.first['zoneName']} • ${stamp(events.first['fixAt'])}',
                  style: TextStyle(
                    fontSize: 10,
                    color: events.isEmpty ? muted : const Color(0xff92400e),
                  ),
                ),
              ),
            ], radius: 24),
            if (sos)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xffef4444),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'SOS ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MiniMap extends StatelessWidget {
  final List<LatLng> points;
  final List<dynamic> zones;
  final bool fresh;
  const MiniMap({
    super.key,
    required this.points,
    this.fresh = false,
    this.zones = const [],
  });
  @override
  Widget build(BuildContext context) => FlutterMap(
    options: MapOptions(
      initialCenter: points.isEmpty ? const LatLng(20.59, 78.96) : points.last,
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
      const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
    ],
  );
}

class ChildDetail extends StatefulWidget {
  final Map<String, dynamic> child;
  const ChildDetail({super.key, required this.child});
  @override
  State<ChildDetail> createState() => _ChildDetailState();
}

class _ChildDetailState extends State<ChildDetail> {
  List<dynamic> history = [];
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
    interval = widget.child['reportIntervalSeconds'] ?? 30;
    batteryThreshold = widget.child['lowBatteryThreshold'] ?? 0;
    speedLimit = widget.child['speedLimitKph'] ?? 0;
    load();
  }

  @override
  void dispose() {
    playback?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final h = await FamilyApi.request('/api/location/history/$id');
      final z = await FamilyApi.request('/api/zones/$id');
      if (mounted)
        setState(() {
          history = h as List? ?? [];
          zones = Map<String, dynamic>.from(z ?? {});
          busy = false;
          error = '';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          busy = false;
          error = 'Could not load this child. Try again.';
        });
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Alert settings saved.')));
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
          const SnackBar(
            content: Text('Saved. Applies on the next successful report.'),
          ),
        );
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save interval.');
    }
  }

  Future<void> addZone() async {
    final name = TextEditingController();
    final radius = TextEditingController(text: '300');
    LatLng? selected = point(widget.child['latest']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Add safe zone'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tap the map to choose the centre.'),
                  SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: selected ?? const LatLng(20.59, 78.96),
                        initialZoom: selected == null ? 4 : 14,
                        onTap: (_, p) => setDialog(() => selected = p),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.childsafety.parent',
                        ),
                        if (selected != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: selected!,
                                child: const Icon(
                                  Icons.location_on,
                                  color: green,
                                ),
                              ),
                            ],
                          ),
                        const SimpleAttributionWidget(
                          source: Text(
                            'OpenStreetMap contributors',
                            style: TextStyle(fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: name,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Zone name'),
                  ),
                  TextField(
                    controller: radius,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Radius: 100-10,000 metres',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
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
            '/api/zones/$id',
            method: 'POST',
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
              () => error = 'Could not add zone. Limit: 10 zones per device.',
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
        content: const Text('This also removes its enter/exit alerts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
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
    playback = Timer.periodic(const Duration(milliseconds: 700), (_) {
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
    final latest = widget.child['latest'] as Map<String, dynamic>?;
    final current = point(latest);
    final pts = ordered.map((x) => point(x)!).toList();
    final shown = playing && pts.isNotEmpty
        ? pts.take(playIndex + 1).toList()
        : current != null
        ? [current]
        : <LatLng>[];
    final safe = zones['zones'] as List? ?? [];
    final sos = history.where((x) => x['emergency'] == true).toList();
    final live = fresh(latest);
    final name = widget.child['childName'] ?? 'Child';
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$name's Dashboard",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                live ? 'Recent GPS fix' : 'Last known location',
                style: TextStyle(fontSize: 10, color: live ? green : muted),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: green,
            unselectedLabelColor: muted,
            indicatorColor: green,
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            tabs: [
              const Tab(text: 'Big Map & History'),
              Tab(text: 'Safe Zones (${safe.length})'),
              const Tab(text: 'SOS Alerts'),
              const Tab(text: 'Sync Interval'),
            ],
          ),
        ),
        body: busy
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  Column(
                    children: [
                      if (error.isNotEmpty)
                        Text(error, style: const TextStyle(color: Colors.red)),
                      Expanded(
                        child: Stack(
                          children: [
                            MiniMap(
                              key: ValueKey('route-$playing-$playIndex'),
                              points: shown,
                              fresh: !playing && live,
                              zones: safe,
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: ink.withValues(alpha: .8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$name • ${playing ? 'Recorded route' : latest?['city'] ?? 'Location unavailable'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            playing
                                                ? 'Historical GPS • gaps may be missing'
                                                : '${safe.length} safe zones • ${latest?['accuracy'] != null ? 'GPS ±${latest!['accuracy']}m' : 'GPS accuracy unavailable'}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 38),
                                        ),
                                        onPressed: pts.isEmpty
                                            ? null
                                            : () => togglePlayback(pts.length),
                                        icon: Icon(
                                          playing
                                              ? Icons.stop
                                              : Icons.play_arrow,
                                          size: 14,
                                        ),
                                        label: Text(
                                          playing
                                              ? 'Stop'
                                              : 'Play Route History',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Text(
                              'Timeline:',
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                            Expanded(
                              child: Slider(
                                value: pts.isEmpty
                                    ? 0
                                    : playIndex
                                          .clamp(0, pts.length - 1)
                                          .toDouble(),
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
                            ),
                            Text(
                              ordered.isEmpty
                                  ? 'No history'
                                  : DateFormat('h:mm a').format(
                                      DateTime.parse(
                                        ordered[playIndex.clamp(
                                          0,
                                          ordered.length - 1,
                                        )]['fixAt'],
                                      ).toLocal(),
                                    ),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GEOFENCED SAFE ZONES',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Alerts need two fresh reports',
                                  style: TextStyle(fontSize: 10, color: muted),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 36),
                            ),
                            onPressed: addZone,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text(
                              'Add Zone',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (safe.isEmpty)
                        panel([
                          const Text(
                            'No safe zones yet',
                            style: TextStyle(color: muted),
                          ),
                        ]),
                      for (final z in safe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: panel([
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffecfdf5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.home_outlined,
                                    color: green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        z['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Radius: ${z['radius']}m',
                                        style: const TextStyle(
                                          fontSize: 10,
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
                                ),
                                IconButton(
                                  onPressed: () => deleteZone(z),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ]),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Recent zone alerts',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final e in zones['events'] as List? ?? [])
                        ListTile(
                          title: Text(
                            '${e['entered'] == true ? 'Entered' : 'Left'} ${e['zoneName']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            stamp(e['fixAt']),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'EMERGENCY SOS HISTORY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (sos.isEmpty)
                        panel([
                          const Text(
                            'No SOS reports received',
                            style: TextStyle(color: muted),
                          ),
                        ]),
                      for (final h in sos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: panel([
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'SOS Button Pressed',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        stamp(h['receivedAt']),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: muted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$name reported an emergency from ${h['city'] ?? 'an unknown location'}.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ]),
                        ),
                      const Text(
                        'Recorded device alerts. No emergency calls or acknowledgement workflow.',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      panel([
                        const Text(
                          'BACKGROUND REPORTING FREQUENCY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Divider(),
                        label('Select Report Interval'),
                        DropdownButtonFormField<int>(
                          initialValue: interval,
                          items: const [
                            DropdownMenuItem(
                              value: 30,
                              child: Text('Every 30 seconds'),
                            ),
                            DropdownMenuItem(
                              value: 60,
                              child: Text('Every 1 minute'),
                            ),
                            DropdownMenuItem(
                              value: 120,
                              child: Text('Every 2 minutes'),
                            ),
                            DropdownMenuItem(
                              value: 300,
                              child: Text('Every 5 minutes'),
                            ),
                            DropdownMenuItem(
                              value: 600,
                              child: Text('Every 10 minutes'),
                            ),
                            DropdownMenuItem(
                              value: 1800,
                              child: Text('Every 30 minutes'),
                            ),
                            DropdownMenuItem(
                              value: 3600,
                              child: Text('Every 1 hour'),
                            ),
                          ],
                          onChanged: (v) => setState(() => interval = v!),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Controls how often $name's phone sends reports. Applies on its next successful report.",
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: saveInterval,
                          child: const Text('Save Interval Setting'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Long intervals can miss short zone visits. GPS may remain active, so battery savings are not guaranteed.',
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                        if (error.isNotEmpty)
                          Text(
                            error,
                            style: const TextStyle(color: Colors.red),
                          ),
                      ]),
                      const SizedBox(height: 16),
                      panel([
                        const Text(
                          'SAFETY ALERTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        label('Low battery threshold'),
                        DropdownButtonFormField<int>(
                          initialValue: batteryThreshold,
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Off')),
                            DropdownMenuItem(value: 10, child: Text('10%')),
                            DropdownMenuItem(value: 15, child: Text('15%')),
                            DropdownMenuItem(value: 20, child: Text('20%')),
                            DropdownMenuItem(value: 30, child: Text('30%')),
                          ],
                          onChanged: (v) =>
                              setState(() => batteryThreshold = v!),
                        ),
                        label('Speed alert'),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Enable speed alert',
                            style: TextStyle(fontSize: 12),
                          ),
                          subtitle: const Text(
                            'Off by default',
                            style: TextStyle(fontSize: 10),
                          ),
                          value: speedLimit > 0,
                          onChanged: (v) =>
                              setState(() => speedLimit = v ? 80 : 0),
                        ),
                        if (speedLimit > 0)
                          Column(
                            children: [
                              Text('$speedLimit km/h'),
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
                        const Text(
                          'Requires two fresh accurate speed reports. GPS speed is an estimate, not a safety guarantee.',
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: saveAlerts,
                          child: const Text('Save Alert Settings'),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      panel([
                        const Text(
                          'OFFLINE REPORTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Updated child app stores up to 2,880 encrypted reports while offline, then uploads them in order when the connection returns. Original GPS times stay unchanged. Old reports are not live location; tracking stops if Android force-stops the app.',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
