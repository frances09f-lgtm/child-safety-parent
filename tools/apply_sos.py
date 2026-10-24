def sub(s, old, new):
    assert s.count(old) == 1, old[:60]
    return s.replace(old, new)
p = 'lib/zone_alerts.dart'
s = open(p, encoding='utf-8').read()
a = s.index("        // SOS: notify once for each new SOS report.\n")
b = s.index("        // Low battery: notify once when the level falls to the threshold.\n")
s = s[:a] + s[b:]
s = sub(s, '  static Future<void> pollExtra({bool silent = false}) async {', "  /// SOS alerts from the server alert list with an id above [after], oldest\n  /// first. Other alert types and entries without a numeric id are skipped.\n  static List<Map<String, dynamic>> sosAlertsAfter(\n    Iterable<dynamic> alerts,\n    int after,\n  ) {\n    final out = alerts\n        .whereType<Map>()\n        .where(\n          (a) =>\n              a['id'] is num &&\n              (a['id'] as num) > after &&\n              (a['type']?.toString().toLowerCase() == 'sos' ||\n                  a['type']?.toString().toLowerCase() == 'emergency'),\n        )\n        .map((a) => Map<String, dynamic>.from(a))\n        .toList()\n      ..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));\n    return out;\n  }\n\n  static Future<void> pollExtra({bool silent = false}) async {")
s = sub(s, "      await FamilyApi.storage.write(key: cursorKey, value: '$latest');\n", "      await FamilyApi.storage.write(key: cursorKey, value: '$latest');\n      // SOS: notify once for each new SOS alert the server recorded. This\n      // reads the alert list instead of the newest location report, so an SOS\n      // is not lost when a normal report arrives right after it. It has its\n      // own cursor, so older SOS alerts are never replayed after an update.\n      final sosCursorKey = 'sosAlertCursor:$account';\n      final sosPrevious = int.tryParse(\n        await FamilyApi.storage.read(key: sosCursorKey) ?? '',\n      );\n      var sosLatest = sosPrevious ?? 0;\n      for (final a in sosAlertsAfter(config['alerts'] as List? ?? [], 0)) {\n        final id = (a['id'] as num).toInt();\n        if (id <= sosLatest) continue;\n        if (!silent && sosPrevious != null) {\n          await _notify(\n            1200000000 + id,\n            a['title']?.toString() ?? 'SOS from a child phone',\n            a['body']?.toString() ??\n                'A child pressed the SOS button. Open the app to see the location.',\n            'sos_alerts',\n            'SOS alerts',\n            {'kind': 'alert', 'account': account, 'device': a['deviceId']},\n            urgent: true,\n          );\n        }\n        sosLatest = id;\n      }\n      await FamilyApi.storage.write(key: sosCursorKey, value: '$sosLatest');\n")
open(p, 'w', encoding='utf-8').write(s)
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()
s = sub(s, "import 'zone_status.dart';\n", "import 'zone_status.dart';\nimport 'sos_order.dart';\n")
s = sub(s, "  final lastFixes = <String, Map<String, dynamic>>{};\n", "  final lastFixes = <String, Map<String, dynamic>>{};\n  final sosRank = <String, int>{};\n")
s = sub(s, "      if (mounted)\n        setState(() {\n          children = data;\n          error = '';\n        });\n    } catch (_) {\n      if (mounted)\n        setState(\n          () => error = 'Could not refresh.", "      try {\n        final feed = await FamilyApi.request('/api/alerts');\n        if (feed is Map) {\n          sosRanks(feed['alerts'] as List? ?? []).forEach((device, rank) {\n            if (rank > (sosRank[device] ?? 0)) sosRank[device] = rank;\n          });\n        }\n      } catch (_) {}\n      if (mounted)\n        setState(() {\n          children = orderBySos(data, sosRank);\n          error = '';\n        });\n    } catch (_) {\n      if (mounted)\n        setState(\n          () => error = 'Could not refresh.")
open(p, 'w', encoding='utf-8').write(s)
for p, pairs in {
    'pubspec.yaml': [('version: 1.4.16+21', 'version: 1.4.17+22')],
    'lib/live/bug_report.dart': [("appVersion = '1.4.16'", "appVersion = '1.4.17'"), ('appBuildNumber = 21', 'appBuildNumber = 22')],
    'test/parent_design_test.dart': [("expect(appVersion, '1.4.16');", "expect(appVersion, '1.4.17');")],
}.items():
    s = open(p, encoding='utf-8').read()
    for o, n in pairs:
        s = sub(s, o, n)
    open(p, 'w', encoding='utf-8').write(s)
print('patched')
