import 'package:flutter_test/flutter_test.dart';
import 'package:child_safety_parent/background_health.dart';
import 'package:child_safety_parent/zone_alerts.dart';

void main() {
  test('warning names what is off', () {
    expect(BackgroundHealth.warning(true, true), isNull);
    expect(
      BackgroundHealth.warning(false, true),
      contains('Notifications are off'),
    );
    expect(BackgroundHealth.warning(true, false), contains('Battery limits'));
    final both = BackgroundHealth.warning(false, false);
    expect(both, contains('Notifications are off'));
    expect(both, contains('battery limits'));
  });

  test('low battery alert fires at or below the threshold only', () {
    expect(ZoneAlerts.isLowBattery(20, 20), isTrue);
    expect(ZoneAlerts.isLowBattery(20, 15), isTrue);
    expect(ZoneAlerts.isLowBattery(20, 21), isFalse);
    expect(ZoneAlerts.isLowBattery(0, 5), isFalse);
  });

  test('clock handles a missing or invalid time', () {
    expect(ZoneAlerts.clock(null), 'a recorded time');
    expect(ZoneAlerts.clock('not a time'), 'a recorded time');
  });
}
