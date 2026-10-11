import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'api.dart';

const green = Color(0xff13984b);
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
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Child Safety Parent',
    debugShowCheckedModeBanner: false,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: const Color(0xfff4f8f5),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: FamilyHome(onTheme: () => setState(() => dark = !dark)),
  );
}

class FamilyHome extends StatefulWidget {
  final VoidCallback onTheme;
  const FamilyHome({super.key, required this.onTheme});
  @override
  State<FamilyHome> createState() => _FamilyHomeState();
}

class _FamilyHomeState extends State<FamilyHome> {
  bool ready = false, signed = false, busy = false;
  String error = '';
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
      timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
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
      await FamilyApi.login(server.text, key.text, email.text, password.text);
      password.clear();
      if (!mounted) return;
      setState(() {
        signed = true;
        busy = false;
        error = '';
      });
      await refresh();
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Child Safety Parent'),
      actions: [
        IconButton(
          onPressed: widget.onTheme,
          icon: const Icon(Icons.dark_mode_outlined),
        ),
        if (signed)
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              timer?.cancel();
              await FamilyApi.logout();
              if (mounted)
                setState(() {
                  signed = false;
                  children = [];
                });
            },
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    body: !ready
        ? const Center(child: CircularProgressIndicator())
        : !signed
        ? loginView()
        : RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'All your children',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'One family account. Reports can be delayed by the phone or network.',
                ),
                const SizedBox(height: 12),
                if (busy) const LinearProgressIndicator(),
                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.red)),
                if (children.isEmpty && !busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No paired child phones yet. Install the child app on each phone, pair it with this parent account, and tap Start tracking.',
                    ),
                  ),
                for (final child in children) childCard(child),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Alerts refresh while this app is open. Push notifications are not connected yet. This app does not call emergency services.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
  );
  Widget loginView() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Icon(Icons.shield_outlined, color: green, size: 54),
      const SizedBox(height: 20),
      const Text(
        'Your family, together',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Text(
        'Sign in with the same parent account used to pair the child phones.',
      ),
      const SizedBox(height: 24),
      TextField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Parent email'),
      ),
      TextField(
        controller: password,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      ExpansionTile(
        title: const Text('Server configuration'),
        children: [
          TextField(
            controller: server,
            decoration: const InputDecoration(
              labelText: 'HTTPS server address',
            ),
          ),
          TextField(
            controller: key,
            decoration: const InputDecoration(
              labelText: 'Firebase public app key',
            ),
          ),
        ],
      ),
      if (error.isNotEmpty)
        Text(error, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: busy ? null : login,
        child: Text(busy ? 'Signing in...' : 'Open family dashboard'),
      ),
      const SizedBox(height: 18),
      const Text(
        'The password is not saved. Session access stays in encrypted Android storage. Explain tracking to each child and use it together.',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );
  Widget childCard(Map<String, dynamic> child) {
    final latest = child['latest'] as Map<String, dynamic>?;
    final p = point(latest);
    final events = (child['zonesData']?['events'] as List?) ?? [];
    final isFresh = fresh(latest) && error.isEmpty;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChildDetail(child: child)),
          );
          await refresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      child['childName'] ?? 'Child',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (latest?['emergency'] == true)
                    const Chip(
                      label: Text('SOS'),
                      backgroundColor: Color(0xffffcdd2),
                    ),
                ],
              ),
              Text(
                isFresh ? 'Recent GPS fix' : 'Last known / no fresh GPS',
                style: TextStyle(
                  color: isFresh ? green : Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text('Report: ${stamp(latest?['receivedAt'])}'),
              Text(
                'Battery: ${latest?['battery'] ?? '--'}% · ${latest?['network'] ?? 'Unknown network'}',
              ),
              if (p != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MiniMap(points: [p], fresh: isFresh),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(latest?['city'] ?? 'Location unavailable'),
              if (events.isNotEmpty)
                Text(
                  '${events.first['entered'] == true ? 'Entered' : 'Left'} ${events.first['zoneName']} · ${stamp(events.first['fixAt'])}',
                ),
              const SizedBox(height: 8),
              const Text(
                'Map, history, safe zones and interval  →',
                style: TextStyle(color: green, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MiniMap extends StatelessWidget {
  final List<LatLng> points;
  final bool fresh;
  const MiniMap({super.key, required this.points, this.fresh = false});
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
  Map<String, dynamic> zones = {};
  Timer? playback;
  int playIndex = 0;
  bool playing = false;
  String get id => Uri.encodeComponent(widget.child['deviceId']);
  @override
  void initState() {
    super.initState();
    interval = widget.child['reportIntervalSeconds'] ?? 30;
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
                          source: Text('OpenStreetMap contributors'),
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

  @override
  Widget build(BuildContext context) {
    final ordered = history.reversed
        .map((x) => Map<String, dynamic>.from(x))
        .where((x) => point(x) != null)
        .toList();
    final points = ordered.map((x) => point(x)!).toList();
    final shown = playing && points.isNotEmpty
        ? points.take(playIndex + 1).toList()
        : points;
    return Scaffold(
      appBar: AppBar(title: Text(widget.child['childName'] ?? 'Child')),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.red)),
                const Text(
                  'Route history',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Recorded positions, not the current route. Gaps may be missing.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: MiniMap(
                    key: ValueKey('${shown.length}'),
                    points: shown,
                  ),
                ),
                TextButton.icon(
                  onPressed: points.isEmpty
                      ? null
                      : () {
                          if (playing) {
                            playback?.cancel();
                            setState(() => playing = false);
                          } else {
                            setState(() {
                              playing = true;
                              playIndex = 0;
                            });
                            playback = Timer.periodic(
                              const Duration(milliseconds: 700),
                              (_) {
                                if (!mounted) return;
                                if (playIndex >= points.length - 1) {
                                  playback?.cancel();
                                  setState(() => playing = false);
                                } else {
                                  setState(() => playIndex++);
                                }
                              },
                            );
                          }
                        },
                  icon: Icon(playing ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    playing ? 'Stop playback' : 'Play recorded route',
                  ),
                ),
                if (playing && ordered.isNotEmpty)
                  Text(stamp(ordered[playIndex]['fixAt'])),
                const Divider(),
                const Text(
                  'Reporting interval',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                DropdownButton<int>(
                  value: interval,
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 sec')),
                    DropdownMenuItem(value: 60, child: Text('1 min')),
                    DropdownMenuItem(value: 120, child: Text('2 min')),
                    DropdownMenuItem(value: 300, child: Text('5 min')),
                    DropdownMenuItem(value: 600, child: Text('10 min')),
                    DropdownMenuItem(value: 1800, child: Text('30 min')),
                    DropdownMenuItem(value: 3600, child: Text('1 hr')),
                  ],
                  onChanged: (v) => setState(() => interval = v!),
                ),
                FilledButton(
                  onPressed: saveInterval,
                  child: const Text('Save interval'),
                ),
                const Text(
                  'Applies after the next report. Faster reports use more battery. Zone alerts need two fresh fixes; long intervals can miss short visits.',
                ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Safe zones',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: addZone,
                      child: const Text('Add zone'),
                    ),
                  ],
                ),
                for (final z in (zones['zones'] as List? ?? []))
                  ListTile(
                    title: Text(z['name']),
                    subtitle: Text(
                      '${z['radius']} m · ${z['inside'] == null
                          ? 'Waiting for GPS'
                          : z['inside'] == true
                          ? 'Last inside'
                          : 'Last outside'}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Delete ${z['name']}?'),
                            content: const Text(
                              'This also removes its enter/exit alerts.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (yes == true) {
                          try {
                            await FamilyApi.request(
                              '/api/zones/$id/${z['id']}',
                              method: 'DELETE',
                            );
                            await load();
                          } catch (_) {
                            if (mounted)
                              setState(() => error = 'Could not delete zone.');
                          }
                        }
                      },
                    ),
                  ),
                const Text(
                  'Recent zone alerts',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                for (final e in (zones['events'] as List? ?? []))
                  ListTile(
                    title: Text(
                      '${e['entered'] == true ? 'Entered' : 'Left'} ${e['zoneName']}',
                    ),
                    subtitle: Text(stamp(e['fixAt'])),
                  ),
                const Divider(),
                const Text(
                  'Location reports',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                for (final h in history.take(100))
                  ListTile(
                    title: Text(h['city'] ?? 'Location unavailable'),
                    subtitle: Text(
                      '${stamp(h['receivedAt'])} · ${h['battery']}%${h['emergency'] == true ? ' · SOS' : ''}',
                    ),
                  ),
                const Text(
                  'No push notifications yet. This app does not call emergency services.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }
}
