import 'package:flutter_test/flutter_test.dart';
import 'package:child_safety_parent/sos_order.dart';
import 'package:child_safety_parent/zone_alerts.dart';

void main() {
  final alerts = [
    {'id': 5, 'type': 'sos', 'deviceId': 'a', 'title': 'Aarav sent SOS'},
    {'id': 6, 'type': 'speed', 'deviceId': 'c'},
    {'id': 9, 'type': 'sos', 'deviceId': 'b'},
    {'id': 12, 'type': 'sos', 'deviceId': 'a'},
    {'id': 'x', 'type': 'sos', 'deviceId': 'c'},
  ];
  List<Map<String, dynamic>> kids(List<String> ids) => [
    for (final id in ids) {'deviceId': id},
  ];
  List<String> ids(List<Map<String, dynamic>> l) =>
      [for (final c in l) c['deviceId'] as String];

  test('newest SOS per child decides the rank', () {
    expect(sosRanks(alerts), {'a': 12, 'b': 9});
  });

  test('child with the newest SOS goes first and the earlier one second', () {
    final ordered = orderBySos(kids(['c', 'b', 'a', 'd']), sosRanks(alerts));
    expect(ids(ordered), ['a', 'b', 'c', 'd']);
  });

  test('a later SOS from another child moves that child above the first', () {
    final more = [
      ...alerts,
      {'id': 20, 'type': 'sos', 'deviceId': 'b'},
    ];
    final ordered = orderBySos(kids(['a', 'b', 'c']), sosRanks(more));
    expect(ids(ordered), ['b', 'a', 'c']);
  });

  test('without any SOS the original order is kept', () {
    final ordered = orderBySos(kids(['c', 'a', 'b']), {});
    expect(ids(ordered), ['c', 'a', 'b']);
  });

  test('an SOS on the latest report with no alert entry goes first', () {
    final list = [
      {'deviceId': 'c'},
      {
        'deviceId': 'd',
        'latest': {'emergency': true},
      },
      {'deviceId': 'a'},
    ];
    final ordered = orderBySos(list, {'a': 12});
    expect(ids(ordered), ['d', 'a', 'c']);
  });

  test('only new SOS alerts are picked for a notification, oldest first', () {
    expect([for (final a in ZoneAlerts.sosAlertsAfter(alerts, 0)) a['id']], [
      5,
      9,
      12,
    ]);
    expect([for (final a in ZoneAlerts.sosAlertsAfter(alerts, 9)) a['id']], [
      12,
    ]);
    expect(ZoneAlerts.sosAlertsAfter(alerts, 12), isEmpty);
  });
}
