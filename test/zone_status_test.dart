import 'package:flutter_test/flutter_test.dart';
import 'package:child_safety_parent/zone_status.dart';

void main() {
  final now = DateTime.utc(2026, 10, 23, 13, 0);
  String at(int minutesAgo) =>
      now.subtract(Duration(minutes: minutesAgo)).toIso8601String();

  test('recent entry shows Inside with zone and time', () {
    final s = zoneStatus({
      'zones': [{'name': 'Home', 'inside': true}],
      'events': [{'entered': true, 'zoneName': 'Home', 'fixAt': at(3)}],
    }, now: now)!;
    expect(s.recent, true);
    expect(s.text, startsWith('Inside Home • '));
  });

  test('recent exit shows Outside with zone and time', () {
    final s = zoneStatus({
      'zones': [{'name': 'Home', 'inside': false}],
      'events': [{'entered': false, 'zoneName': 'Home', 'fixAt': at(9)}],
    }, now: now)!;
    expect(s.recent, true);
    expect(s.text, startsWith('Outside Home • '));
  });

  test('crossing older than 10 minutes expires to plain state', () {
    final s = zoneStatus({
      'zones': [{'name': 'Home', 'inside': true}],
      'events': [{'entered': true, 'zoneName': 'Home', 'fixAt': at(11)}],
    }, now: now)!;
    expect(s.recent, false);
    expect(s.text, 'Inside Home');
  });

  test('old exit shows plain Outside without a time', () {
    final s = zoneStatus({
      'zones': [{'name': 'Home', 'inside': false}],
      'events': [{'entered': false, 'zoneName': 'Home', 'fixAt': at(300)}],
    }, now: now)!;
    expect(s.recent, false);
    expect(s.text, 'Outside Home');
  });

  test('newest event wins and nothing shows without data', () {
    final s = zoneStatus({
      'events': [
        {'entered': true, 'zoneName': 'Home', 'fixAt': at(8)},
        {'entered': false, 'zoneName': 'School', 'fixAt': at(2)},
      ],
    }, now: now)!;
    expect(s.text, startsWith('Outside School • '));
    expect(zoneStatus(null, now: now), isNull);
    expect(zoneStatus({'zones': [], 'events': []}, now: now), isNull);
  });
}
