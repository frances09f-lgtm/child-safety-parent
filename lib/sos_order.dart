/// Children tab ordering for SOS. The newest SOS alert id per child decides
/// the rank, so the child who pressed SOS last is first, the one before is
/// second, and children without an SOS keep their original order after them.
Map<String, int> sosRanks(Iterable<dynamic> alerts) {
  final ranks = <String, int>{};
  for (final a in alerts.whereType<Map>()) {
    final type = a['type']?.toString().toLowerCase();
    final id = a['id'];
    final device = a['deviceId']?.toString();
    if ((type != 'sos' && type != 'emergency') || id is! num || device == null) {
      continue;
    }
    final rank = id.toInt();
    if (rank > (ranks[device] ?? 0)) ranks[device] = rank;
  }
  return ranks;
}

List<Map<String, dynamic>> orderBySos(
  List<Map<String, dynamic>> children,
  Map<String, int> ranks,
) {
  final top = ranks.values.fold<int>(0, (a, b) => a > b ? a : b);
  int rankOf(Map<String, dynamic> c) {
    final known = ranks[c['deviceId']?.toString()];
    if (known != null) return known;
    // An SOS still showing on the latest report but missing from the alert
    // list counts as the newest one.
    final latest = c['latest'];
    return latest is Map && latest['emergency'] == true ? top + 1 : 0;
  }

  final indexed = [for (var i = 0; i < children.length; i++) (i, children[i])];
  indexed.sort((a, b) {
    final byRank = rankOf(b.$2).compareTo(rankOf(a.$2));
    return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
