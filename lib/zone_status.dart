import 'package:intl/intl.dart';

/// How long a zone crossing box stays on the child card.
const Duration zoneAlertLifetime = Duration(minutes: 10);

class ZoneStatus {
  const ZoneStatus(this.text, {required this.recent});

  final String text;

  /// True while the last crossing is newer than [zoneAlertLifetime].
  final bool recent;
}

DateTime? _zoneTime(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();

/// Text for the zone box on a child card, or null when there is nothing
/// worth showing. Recent crossings (under 10 minutes) show the state with
/// the crossing time. Older crossings show only the plain state.
ZoneStatus? zoneStatus(dynamic zonesData, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final data = zonesData is Map ? zonesData : const {};
  final events = (data['events'] as List? ?? [])
      .whereType<Map>()
      .map((e) => MapEntry(_zoneTime(e['fixAt']), e))
      .where((e) => e.key != null)
      .toList()
    ..sort((a, b) => b.key!.compareTo(a.key!));
  if (events.isNotEmpty) {
    final at = events.first.key!;
    final e = events.first.value;
    final age = clock.difference(at);
    if (age < zoneAlertLifetime && age > const Duration(minutes: -5)) {
      final inside = e['entered'] == true;
      return ZoneStatus(
        '${inside ? 'Inside' : 'Outside'} ${e['zoneName'] ?? 'safe zone'} • ${DateFormat('d MMM, h:mm a').format(at)}',
        recent: true,
      );
    }
  }
  final zones = (data['zones'] as List? ?? []).whereType<Map>().toList();
  final inside = zones.where((z) => z['inside'] == true).toList();
  if (inside.isNotEmpty) {
    return ZoneStatus(
      'Inside ${inside.map((z) => z['name']).join(', ')}',
      recent: false,
    );
  }
  if (zones.any((z) => z['inside'] == false)) {
    final known = zones.where((z) => z['inside'] == false).toList();
    return ZoneStatus(
      known.length == 1 && zones.length == 1
          ? 'Outside ${known.first['name']}'
          : 'Outside all safe zones',
      recent: false,
    );
  }
  if (events.isNotEmpty) {
    final latest = <String, bool>{};
    for (final e in events) {
      latest.putIfAbsent(
        e.value['zoneName']?.toString() ?? 'safe zone',
        () => e.value['entered'] == true,
      );
    }
    final names = latest.entries.where((e) => e.value).map((e) => e.key).toList();
    if (names.isNotEmpty) {
      return ZoneStatus('Inside ${names.join(', ')}', recent: false);
    }
    return latest.length == 1
        ? ZoneStatus('Outside ${latest.keys.first}', recent: false)
        : const ZoneStatus('Outside all safe zones', recent: false);
  }
  return null;
}
