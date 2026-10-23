import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api.dart';
import 'main.dart' show ParentTheme, surface, accent, tonal, edge;

Color get _green => accent;
Color get _ink =>
    ParentTheme.dark.value ? Color(0xffe9f1ec) : Color(0xff14201b);
Color get _muted =>
    ParentTheme.dark.value ? Color(0xff9aa8a2) : Color(0xff5c6b63);

String _dur(num? ms) {
  if (ms == null) return 'Unavailable';
  final m = (ms / 60000).round();
  return m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min';
}

String _clock(num? ms) => ms == null
    ? '-'
    : DateFormat('h:mm a')
          .format(DateTime.fromMillisecondsSinceEpoch(ms.toInt()));

/// Phone Activity tab: counts reported by the child's phone (screen time, unlocks, app usage...).
class ActivityTab extends StatefulWidget {
  final String deviceId;
  ActivityTab({super.key, required this.deviceId});
  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  bool busy = true;
  String error = '';
  List<Map<String, dynamic>> days = [];
  String? lastSync;
  int range = 14;
  String? selected;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final end = DateTime.now().add(Duration(days: 1));
      final start = end.subtract(Duration(days: range + 1));
      final f = DateFormat('yyyy-MM-dd');
      final r = await FamilyApi.request(
        '/api/activity/${Uri.encodeComponent(widget.deviceId)}?from=${f.format(start)}&to=${f.format(end)}',
      );
      final list = ((r?['days'] as List?) ?? [])
          .map(
            (e) => {
              'day': e['day'],
              'updatedAt': e['updatedAt'],
              ...Map<String, dynamic>.from(e['data'] as Map),
            },
          )
          .toList();
      if (!mounted) return;
      setState(() {
        days = list.cast<Map<String, dynamic>>();
        lastSync = r?['lastSync']?.toString();
        selected = days.isEmpty
            ? null
            : (days.any((d) => d['day'] == selected)
                  ? selected
                  : days.last['day'] as String);
        busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Could not load phone activity. Pull to retry.';
        busy = false;
      });
    }
  }

  Map<String, dynamic>? get cur => days
      .where((d) => d['day'] == selected)
      .cast<Map<String, dynamic>?>()
      .firstOrNull;

  num _sum(Iterable<Map<String, dynamic>> l, String k) =>
      l.fold<num>(0, (a, d) => a + ((d[k] as num?) ?? 0));

  Widget _card(String title, Widget child) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(bottom: 12),
    padding: EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: surface,
      border: Border.all(color: edge),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        SizedBox(height: 8),
        child,
      ],
    ),
  );

  Widget _stat(String t, String v) => Expanded(
    child: Container(
      margin: EdgeInsets.all(3),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tonal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          Text(t, style: TextStyle(fontSize: 13, color: _muted)),
        ],
      ),
    ),
  );

  Widget _empty(String t) => Padding(
    padding: EdgeInsets.symmetric(vertical: 6),
    child: Text(t, style: TextStyle(fontSize: 13, color: _muted)),
  );

  @override
  Widget build(BuildContext context) {
    if (busy) return Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (error.isNotEmpty)
            Text(error, style: TextStyle(color: Colors.red)),
          Wrap(
            spacing: 6,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Range', style: TextStyle(fontSize: 13, color: _muted)),
              SizedBox(width: 8),
              for (final r in [7, 14, 30])
                Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('$r days'),
                    selectedColor: _green,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: range == r
                          ? (ParentTheme.dark.value
                                ? const Color(0xff06201a)
                                : Colors.white)
                          : _ink,
                    ),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    selected: range == r,
                    onSelected: (_) {
                      range = r;
                      load();
                    },
                  ),
                ),
              Text(
                lastSync == null
                    ? 'Last synced: never'
                    : 'Last synced: ${DateFormat('d MMM, h:mm a').format(DateTime.parse(lastSync!).toLocal())}',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (days.isEmpty)
            _card(
              'No phone activity yet',
              _empty(
                'The child phone has not uploaded any activity. On the child phone, open the app, find Phone activity and turn it on (the child phone must have Child Safety Tracker v9 or newer). Then grant Usage access. The first upload can take up to 15 minutes.',
              ),
            )
          else ...[
            _card(
              'Estimated phone activity',
              Builder(
                builder: (context) {
                  final motion = days.last['activityRecognition'] as Map?;
                  final at = motion?['observedAt'] as num?;
                  return Text(
                    motion == null
                        ? 'Unavailable: update the child app and enable activity detection.'
                        : "${motion['state'] ?? 'Unknown'} - ${motion['status'] ?? 'Unknown'}\nLast transition: ${at == null ? 'none' : DateFormat('d MMM, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(at.toInt()))}\nUploaded with phone activity. Estimates can be delayed or wrong; not a live guarantee.",
                    style: TextStyle(color: _ink, fontSize: 13, height: 1.5),
                  );
                },
              ),
            ),
            _card('Last ${days.length} days (tap a bar)', _chart()),
            _dayDetail(),
            _weekly(),
          ],
          SizedBox(height: 20),
          Text(
            'Counts only, reported by the child phone with the family\'s consent. Messages, passwords, keystrokes, screens and notification text are never collected. A value that shows Unavailable was not provided by Android.',
            style: TextStyle(fontSize: 13, color: _muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _chart() {
    final maxMs = days
        .map((d) => ((d['screenOnMs'] as num?) ?? 0).toDouble())
        .fold<double>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => selected = d['day'] as String),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      ((d['screenOnMs'] as num?) ?? 0) == 0
                          ? ''
                          : '${(((d['screenOnMs'] as num) / 3600000)).toStringAsFixed(1)}h',
                      style: TextStyle(fontSize: 8, color: _muted),
                    ),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      height: (((d['screenOnMs'] as num?) ?? 0) / maxMs * 80)
                          .clamp(2, 80)
                          .toDouble(),
                      decoration: BoxDecoration(
                        color: d['day'] == selected
                            ? _green
                            : _green.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      (d['day'] as String).substring(8),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: d['day'] == selected
                            ? FontWeight.w800
                            : FontWeight.w400,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayDetail() {
    final d = cur;
    if (d == null) return SizedBox();
    final avail = Map<String, dynamic>.from(d['avail'] as Map? ?? {});
    final apps = (d['apps'] as List?) ?? [];
    final notifs = (d['notifications'] as List?) ?? [];
    final cats = (d['categories'] as List?) ?? [];
    final wifi = (d['wifi'] as List?) ?? [];
    final bt = (d['bluetooth'] as List?) ?? [];
    final ch = (d['charging'] as List?) ?? [];
    final ringer = [
      ...((d['ringer'] as List?) ?? []),
      ...((d['dnd'] as List?) ?? []),
    ];
    final perms = (d['permissions'] as List?) ?? [];
    final hourly = ((d['hourlyMs'] as List?) ?? [])
        .map((e) => (e as num).toDouble())
        .toList();
    final motion = Map<String, dynamic>.from(d['motion'] as Map? ?? {});
    final day = DateFormat('EEE, d MMM').format(DateTime.parse(d['day']));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          day,
          Column(
            children: [
              Row(
                children: [
                  _stat('Unlocks', d['unlocks']?.toString() ?? 'Unavailable'),
                  _stat('Screen-on', _dur(d['screenOnMs'] as num?)),
                ],
              ),
              Row(
                children: [
                  _stat(
                    'Night use ${d['nightStartHour']}:00-${d['nightEndHour']}:00',
                    _dur(d['nightScreenMs'] as num?),
                  ),
                  _stat('Avg session', _dur(d['avgSessionMs'] as num?)),
                ],
              ),
              Row(
                children: [
                  _stat('First activity', _clock(d['firstActive'] as num?)),
                  _stat('Last activity', _clock(d['lastActive'] as num?)),
                ],
              ),
              Row(
                children: [
                  _stat('Restarts', '${d['restarts'] ?? 0}'),
                  _stat('Sessions', d['sessions']?.toString() ?? 'Unavailable'),
                ],
              ),
              if (avail['usageAccess'] != true)
                _empty(
                  'Permission Required on the child phone: Usage access (needed for app time, opens and exact unlocks).',
                ),
            ],
          ),
        ),
        _card(
          'Daily timeline (screen-on by hour)',
          hourly.length != 24
              ? _empty('No timeline')
              : SizedBox(
                  height: 70,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var h = 0; h < 24; h++)
                        Expanded(
                          child: Tooltip(
                            message: '$h:00  ${_dur(hourly[h])}',
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: .8),
                              height: (hourly[h] / 3600000 * 60)
                                  .clamp(1, 60)
                                  .toDouble(),
                              color: hourly[h] > 0 ? _green : Colors.black12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        _card(
          'Most-used apps',
          avail['appUsage'] != true && apps.isEmpty
              ? _empty('Permission Required: Usage access on the child phone.')
              : apps.isEmpty
              ? _empty('No app use recorded.')
              : Column(
                  children: [
                    for (final a in apps.take(10))
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${a['label']}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '${_dur(a['ms'] as num?)}  ·  ${a['opens']} opens',
                              style: TextStyle(fontSize: 11, color: _muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (cats.isNotEmpty)
          _card(
            'App categories',
            Column(
              children: [
                for (final c in cats)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${c['category']}',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          _dur(c['ms'] as num?),
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        _card(
          'Notifications received (counts only)',
          avail['notifications'] != true && notifs.isEmpty
              ? _empty(
                  'Permission Required: Notification access on the child phone (optional).',
                )
              : notifs.isEmpty
              ? _empty('None recorded.')
              : Column(
                  children: [
                    for (final n in notifs.take(10))
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${n['label']}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '${n['count']}',
                              style: TextStyle(fontSize: 11, color: _muted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        _card(
          'Wi-Fi and Bluetooth',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wifi.isEmpty && bt.isEmpty)
                _empty('No Wi-Fi or Bluetooth changes recorded.'),
              for (final e in wifi)
                Text(
                  '${_clock(e['t'] as num)}  Wi-Fi ${e['e']}',
                  style: TextStyle(fontSize: 13),
                ),
              for (final e in bt)
                Text(
                  '${_clock(e['t'] as num)}  Bluetooth ${e['e']}',
                  style: TextStyle(fontSize: 13),
                ),
            ],
          ),
        ),
        _card(
          'Charging',
          ch.isEmpty
              ? _empty('No charging sessions recorded.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in ch)
                      Text(
                        '${_clock(c['start'] as num?)} to ${c['end'] == null ? 'now' : _clock(c['end'] as num)}   ${c['startLevel'] ?? '?'}% to ${c['endLevel'] ?? '?'}%',
                        style: TextStyle(fontSize: 13),
                      ),
                  ],
                ),
        ),
        _card(
          'Ringer and Do Not Disturb',
          ringer.isEmpty
              ? _empty('No changes recorded.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in ringer)
                      Text(
                        '${_clock(e['t'] as num)}  ${e['e']}',
                        style: TextStyle(fontSize: 13),
                      ),
                  ],
                ),
        ),
        _card(
          'Permission changes on the child phone',
          perms.isEmpty
              ? _empty('No changes recorded.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in perms)
                      Text(
                        '${_clock(p['t'] as num)}  ${p['name']} ${p['granted'] == true ? 'allowed' : 'turned off'}',
                        style: TextStyle(fontSize: 13),
                      ),
                  ],
                ),
        ),
        _card(
          'Motion (approximate)',
          avail['motionSensor'] != true
              ? _empty('Unavailable on this phone.')
              : _empty(
                  '${motion['events'] ?? 0} significant-motion events. Longest gap between them: ${_dur(motion['longestGapMs'] as num?)}.',
                ),
        ),
      ],
    );
  }

  Widget _weekly() {
    if (days.isEmpty) return SizedBox();
    final last = days.length >= 7 ? days.sublist(days.length - 7) : days;
    final prev = days.length >= 14
        ? days.sublist(days.length - 14, days.length - 7)
        : <Map<String, dynamic>>[];
    String delta(num a, num b) {
      if (prev.isEmpty || b == 0) return '';
      final p = ((a - b) / b * 100).round();
      return p == 0
          ? ' (same as last week)'
          : ' (${p > 0 ? '+' : ''}$p% vs last week)';
    }

    final apps = <String, num>{};
    for (final d in last) {
      for (final a in (d['apps'] as List? ?? [])) {
        apps[a['label'] as String] =
            (apps[a['label']] ?? 0) + ((a['ms'] as num?) ?? 0);
      }
    }
    final top = apps.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final screen = _sum(last, 'screenOnMs'),
        unl = _sum(last, 'unlocks'),
        night = _sum(last, 'nightScreenMs');
    return _card(
      'Weekly report (last ${last.length} days)',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total screen time: ${_dur(screen)}${delta(screen, _sum(prev, 'screenOnMs'))}',
            style: TextStyle(fontSize: 13),
          ),
          Text(
            'Average per day: ${_dur(screen / last.length)}',
            style: TextStyle(fontSize: 13),
          ),
          Text(
            'Unlocks: ${unl.round()}${delta(unl, _sum(prev, 'unlocks'))}',
            style: TextStyle(fontSize: 13),
          ),
          Text(
            'Night-time use: ${_dur(night)}${delta(night, _sum(prev, 'nightScreenMs'))}',
            style: TextStyle(fontSize: 13),
          ),
          SizedBox(height: 6),
          Text(
            'Most-used apps',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (top.isEmpty) _empty('No app usage in this period.'),
          for (final e in top.take(5))
            Text('${e.key}: ${_dur(e.value)}', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
