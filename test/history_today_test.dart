import 'package:flutter_test/flutter_test.dart';
import 'package:child_safety_parent/history_today.dart';

void main() {
  test('keeps only entries from today in India time, newest first', () {
    final now = DateTime.utc(2026, 10, 23, 8, 30);
    final items = <Map<String, dynamic>>[
      {'fixAt': '2026-10-23T02:00:00Z'},
      {'fixAt': '2026-10-22T18:29:59Z'},
      {'fixAt': '2026-10-22T18:30:00Z'},
      {'fixAt': '2026-10-23T08:00:00Z'},
      {'fixAt': 'bad'},
      {'fixAt': null},
      {'fixAt': '2026-10-21T10:00:00Z'},
    ];
    final r = todayHistory(items, now);
    expect(r.map((e) => e['fixAt']).toList(), [
      '2026-10-23T08:00:00Z',
      '2026-10-23T02:00:00Z',
      '2026-10-22T18:30:00Z',
    ]);
  });

  test('day rolls over at midnight India time, not UTC', () {
    final now = DateTime.utc(2026, 10, 23, 19, 0);
    final items = <Map<String, dynamic>>[
      {'fixAt': '2026-10-23T18:45:00Z'},
      {'fixAt': '2026-10-23T10:00:00Z'},
    ];
    final r = todayHistory(items, now);
    expect(r.map((e) => e['fixAt']).toList(), ['2026-10-23T18:45:00Z']);
  });

  test('returns empty list when nothing is from today', () {
    final now = DateTime.utc(2026, 10, 23, 8, 30);
    final items = <Map<String, dynamic>>[
      {'fixAt': '2026-10-20T10:00:00Z'},
    ];
    expect(todayHistory(items, now), isEmpty);
    expect(todayHistory(<Map<String, dynamic>>[], now), isEmpty);
  });
}
