import re, sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()
if "import 'background_health.dart';" not in s:
    s = s.replace("import 'zone_alerts.dart';\n", "import 'zone_alerts.dart';\nimport 'background_health.dart';\n", 1)
old = "    padding: EdgeInsets.fromLTRB(16, 4, 16, 116),\n    children: [\n      panel(["
assert s.count(old) == 1, 'settings list not found'
s = s.replace(old, "    padding: EdgeInsets.fromLTRB(16, 4, 16, 116),\n    children: [\n      const BackgroundWarning(),\n      panel([", 1)
old = "Background: Android schedules checks from 15 minutes; battery limits, no internet or force-stop can delay or stop alerts. Not instant push."
assert s.count(old) == 1, 'note not found'
s = s.replace(old, "Also runs while the app is closed: a small always-on notice keeps checks running about every 30 seconds. Battery limits, no internet or force-stop can delay or stop alerts.", 1)
open(p, 'w', encoding='utf-8').write(s)
print('main.dart patched')
