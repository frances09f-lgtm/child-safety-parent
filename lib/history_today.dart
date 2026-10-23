// Keeps only history entries from today in India time (Asia/Kolkata), newest first.
const _istOffset = Duration(hours: 5, minutes: 30);

DateTime? _fixTime(dynamic v) => DateTime.tryParse(v?.toString() ?? '');

bool isTodayInIndia(dynamic fixAt, [DateTime? now]) {
  final d = _fixTime(fixAt);
  if (d == null) return false;
  final n = (now ?? DateTime.now()).toUtc().add(_istOffset);
  final x = d.toUtc().add(_istOffset);
  return x.year == n.year && x.month == n.month && x.day == n.day;
}

List<Map<String, dynamic>> todayHistory(
  Iterable<Map<String, dynamic>> items, [
  DateTime? now,
]) {
  final out = items.where((h) => isTodayInIndia(h['fixAt'], now)).toList();
  out.sort((a, b) => _fixTime(b['fixAt'])!.compareTo(_fixTime(a['fixAt'])!));
  return out;
}
