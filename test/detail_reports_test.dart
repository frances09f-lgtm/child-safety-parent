import 'package:flutter_test/flutter_test.dart';
import 'package:child_safety_parent/detail_reports.dart';

Map<String, dynamic> fix(String device, String at, double lat) => {
  'deviceId': device,
  'hasFix': true,
  'fixAt': at,
  'latitude': lat,
  'longitude': 74.0,
};
void main() {
  test('new history beats captured latest by original GPS time', () {
    final old = fix('a', '2026-01-01T08:00:00Z', 16);
    final next = fix('a', '2026-01-01T08:01:00Z', 17);
    expect(newestDeviceFix('a', [old, next])?['latitude'], 17);
  });
  test('no-fix report preserves last-known timestamp', () {
    final old = fix('a', '2026-01-01T08:00:00Z', 16);
    expect(
      newestDeviceFix('a', [
        old,
        {'deviceId': 'a', 'hasFix': false},
      ])?['fixAt'],
      old['fixAt'],
    );
  });
  test('cross-device and invalid fixes never win', () {
    final old = fix('a', '2026-01-01T08:00:00Z', 16);
    expect(
      newestDeviceFix('a', [
        old,
        fix('b', '2026-01-02T08:00:00Z', 17),
        fix('a', 'invalid', 18),
        fix('a', '2026-01-03T08:00:00Z', 100),
      ])?['latitude'],
      16,
    );
  });
  test('arrival time cannot make old GPS fresh', () {
    final old = fix('a', '2026-01-01T08:00:00Z', 16)
      ..['receivedAt'] = '2026-01-03T08:00:00Z';
    expect(
      newestDeviceFix('a', [
        fix('a', '2026-01-02T08:00:00Z', 17),
        old,
      ])?['latitude'],
      17,
    );
  });
}
