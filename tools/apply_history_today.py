import re


def sub(path, old, new):
    s = open(path).read()
    assert s.count(old) == 1, (path, old[:40], s.count(old))
    open(path, 'w').write(s.replace(old, new))


sub('lib/main.dart', "import 'zone_alerts.dart';\n", "import 'zone_alerts.dart';\nimport 'history_today.dart';\n")
sub(
    'lib/main.dart',
    "                        draftTitle('Recent fixes'),\n"
    "                        const SizedBox(height: 10),\n"
    "                        if (ordered.isEmpty)\n"
    "                          Text(\n"
    "                            'No recorded fixes yet',\n"
    "                            style: TextStyle(color: muted),\n"
    "                          ),\n"
    "                        for (final h in ordered.reversed)\n",
    "                        draftTitle('Recent history'),\n"
    "                        const SizedBox(height: 10),\n"
    "                        if (todayHistory(ordered).isEmpty)\n"
    "                          Text(\n"
    "                            'No history today',\n"
    "                            style: TextStyle(color: muted),\n"
    "                          ),\n"
    "                        for (final h in todayHistory(ordered))\n",
)
sub('pubspec.yaml', 'version: 1.4.11+16', 'version: 1.4.12+17')
sub('lib/live/bug_report.dart', "appVersion = '1.4.11'", "appVersion = '1.4.12'")
sub('lib/live/bug_report.dart', 'appBuildNumber = 16', 'appBuildNumber = 17')
sub('test/parent_design_test.dart', "expect(appVersion, '1.4.11');", "expect(appVersion, '1.4.12');")
sub('test/parent_design_test.dart', 'expect(appBuildNumber, 16);', 'expect(appBuildNumber, 17);')
print('applied')
