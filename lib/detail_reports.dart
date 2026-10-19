// Pick a fix by its original GPS time, never report/upload arrival time.
Map<String, dynamic>? newestDeviceFix(
  String deviceId,
  Iterable<dynamic> reports,
) {
  Map<String, dynamic>? newest;
  DateTime? newestAt;
  for (final value in reports) {
    if (value is! Map ||
        value['deviceId'] != deviceId ||
        value['hasFix'] != true)
      continue;
    final lat = value['latitude'], lon = value['longitude'];
    final at = DateTime.tryParse(value['fixAt']?.toString() ?? '');
    if (lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        at == null)
      continue;
    if (newestAt == null || at.isAfter(newestAt)) {
      newestAt = at;
      newest = Map<String, dynamic>.from(value);
    }
  }
  return newest;
}
