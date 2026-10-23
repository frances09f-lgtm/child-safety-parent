from pathlib import Path
import re

p=Path('lib/main.dart'); original=p.read_text(); s=original
# Only presentation builders are replaced. Network, login, refresh and action methods stay byte-identical.
s=s.replace("import 'activity.dart';", "import 'activity.dart';\nimport 'live/bug_report.dart';")
s=s.replace('const green = Color(0xff2f6b5e);', 'Color get green => ParentTheme.dark.value ? const Color(0xff8fd8c2) : const Color(0xff2f6b5e);\nColor get tonal => ParentTheme.dark.value ? const Color(0xff1a2422) : const Color(0xffeaf1ea);\nColor get danger => ParentTheme.dark.value ? const Color(0xffff8a80) : const Color(0xffb3261e);\nColor get amber => ParentTheme.dark.value ? const Color(0xff2a2312) : const Color(0xfffbf1d9);\nColor get onAmber => ParentTheme.dark.value ? const Color(0xfff2d48a) : const Color(0xff6b4e12);')
s=s.replace('Widget pill(String text, {Color color = green})', 'Widget pill(String text, {Color? color})').replace('color: color.withValues(alpha: .1)', 'color: (color ?? accent).withValues(alpha: .12)').replace('fontSize: 10, color: color, fontWeight: FontWeight.w700', 'fontSize: 12, color: color ?? accent, fontWeight: FontWeight.w600')
a=s.index('  @override\n  Widget build(BuildContext context) => Scaffold(', s.index('class _FamilyHomeState'))
b=s.index('  Widget loginView()',a)
s=s[:a]+'''  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: signed,
    backgroundColor: pale,
    appBar: !signed ? null : SafetyHeader(
      title: section == 0 ? 'Your Family' : 'Settings',
      actions: [SafetyIconButton(icon: Icons.settings_outlined, label: 'Settings', onTap: () => setState(() => section = 1))],
    ),
    bottomNavigationBar: !signed ? null : SafetyDock(
      index: section, onTap: (v) => setState(() => section = v),
      items: const [SafetyDockItem(Icons.phone_android_outlined, 'Children'), SafetyDockItem(Icons.settings_outlined, 'Settings')],
    ),
    body: !ready ? const Center(child: CircularProgressIndicator()) : !signed ? loginView() : section == 1 ? settingsView() : RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 116),
        children: [
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${children.length} protected devices connected', style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w700, letterSpacing: .7)),
            const SizedBox(height: 4), Text('Your Family', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 19, fontWeight: FontWeight.w700, color: ink)),
          ])), SafetyIconButton(icon: Icons.refresh, label: 'Refresh reports', onTap: busy ? null : refresh)],),
          const SizedBox(height: 16),
          if (busy) const LinearProgressIndicator(),
          if (error.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(error, style: TextStyle(color: danger))),
          if (children.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(
            onChanged: (v) => setState(() => childSearch = v),
            decoration: InputDecoration(hintText: 'Search children', prefixIcon: Icon(Icons.search, color: muted, size: 20), filled: true, fillColor: tonal,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none)),
          )),
          if (children.isEmpty && !busy) panel([Text('No paired child phones yet', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 19, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text('Pair each child phone with this account and start tracking.', style: TextStyle(color: muted, fontSize: 13, height: 1.45))]),
          for (final child in children.where((c) { final q = childSearch.trim().toLowerCase(); if (q.isEmpty) return true; return '${c['name']}'.toLowerCase().contains(q) || '${c['deviceId']}'.toLowerCase().contains(q); })) childCard(child),
          Text('Reports refresh while open. Push notifications are not connected yet. This app does not call emergency services.', style: TextStyle(fontSize: 13, color: muted, height: 1.45)),
        ],
      ),
    ),
  );
''' + s[b:]
a=s.index('  Widget childCard('); b=s.index('\n}\n\nclass MiniMap',a)
s=s[:a]+'''  Widget childCard(Map<String, dynamic> child) {
    final latest = child['latest'] as Map<String, dynamic>?;
    final location = child['locationFix'] as Map<String, dynamic>? ?? latest;
    final p = point(location);
    final events = child['zonesData']?['events'] as List? ?? [];
    final live = fresh(latest) && error.isEmpty;
    final name = child['childName']?.toString() ?? 'Child';
    final sos = latest?['emergency'] == true;
    Widget stat(String title, String value) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), decoration: BoxDecoration(color: tonal, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: muted, letterSpacing: .5)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ink))]),
    ));
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Stack(clipBehavior: Clip.none, children: [panel([
      InkWell(borderRadius: BorderRadius.circular(18), onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ChildDetail(child: child))); await refresh(); }, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(radius: 24, backgroundColor: soft, foregroundColor: onSoft, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(fontFamily: 'Space Grotesk', fontSize: 18, fontWeight: FontWeight.w700))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(fontSize: 16, color: ink, fontWeight: FontWeight.w700)), Text('Android • ${child['deviceId']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: muted)), const SizedBox(height: 5), pill(live ? 'Live' : 'Last known', color: live ? accent : onAmber)]))]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 96, child: Stack(children: [
          if (p != null) MiniMap(points: [p], fresh: live) else Container(color: tonal, child: Center(child: Text('Location unavailable', style: TextStyle(color: muted)))),
          Positioned(left: 8, bottom: 8, right: 8, child: Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999)), child: Text('${location?['city'] ?? 'Unknown location'}${location?['accuracy'] != null ? ' • ±${location!['accuracy']}m' : ''}', maxLines: 2, style: TextStyle(color: ink, fontSize: 10.5, fontWeight: FontWeight.w700))))),
        ]))),
        const SizedBox(height: 10), Row(children: [stat('BATTERY', '${latest?['battery'] ?? '--'}%'), const SizedBox(width: 8), stat('LAST REPORT', ago(latest?['receivedAt'])), const SizedBox(width: 8), stat('STATUS', live ? 'Live' : p == null ? 'No GPS fix' : 'Stale')]),
        const SizedBox(height: 10), Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: events.isEmpty ? tonal : amber, borderRadius: BorderRadius.circular(14)), child: Text(events.isEmpty ? 'No zone alerts yet' : 'Zone Alert: ${events.first['entered'] == true ? 'Entered' : 'Left'} ${events.first['zoneName']} • ${stamp(events.first['fixAt'])}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: events.isEmpty ? muted : onAmber))),
      ])),
      const SizedBox(height: 14), Row(children: [Expanded(child: Text(live ? 'Updated while the dashboard is open.' : p == null ? 'No GPS fix reported yet.' : 'Last known location • ${stamp(location?['fixAt'])}', style: TextStyle(fontSize: 13, height: 1.45, color: muted))), TextButton(onPressed: () => removeChild(child), style: TextButton.styleFrom(foregroundColor: danger), child: const Text('Remove device', style: TextStyle(fontSize: 13, decoration: TextDecoration.underline)))]),
    ]), if (sos) Positioned(top: -9, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: danger, borderRadius: BorderRadius.circular(999)), child: Text('SOS ACTIVE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: pale, letterSpacing: 1.1))))]));
  }
''' + s[b:]
# Settings keeps every existing callback. Rebuild its presentation to readable draft sizing and grouped account/actions.
a=s.index('  Widget settingsView()'); b=s.index('  Future<void> removeChild', a)
t=s[a:b].replace('padding: EdgeInsets.all(16)', 'padding: EdgeInsets.fromLTRB(16, 4, 16, 116)')
t=t.replace('fontSize: 10', 'fontSize: 13').replace('fontSize: 11', 'fontSize: 13').replace('fontSize: 12', 'fontSize: 15')
t=t.replace('FontWeight.w800', 'FontWeight.w700').replace('Color(0xffdc2626)', 'danger')
t=t.replace("Text(\n                    FamilyApi.email", "Text(\n                    FamilyApi.email")
t=t.replace('style: TextStyle(fontWeight: FontWeight.w700),\n                  ),', "style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 19, fontWeight: FontWeight.w700),\n                  ),",1)
t=t.replace("Text(ParentPush.status,", "Text(ParentPush.status,")
t=t.replace("      Padding(\n        padding: EdgeInsets.all(12),", "      panel([Text('App version', style: TextStyle(color: muted, fontSize: 13)), SizedBox(height: 4), Text('v$appVersion', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 19, fontWeight: FontWeight.w700))]),\n      Padding(\n        padding: EdgeInsets.all(12),")
s=s[:a]+t+s[b:]
# Replace the whole child-detail presentation; retain existing state and actions verbatim.
a=s.index('  @override\n  Widget build(BuildContext context) {',s.index('class _ChildDetailState'))
b=s.index('    return DefaultTabController(',a)
s=s[:b]+'''    return DefaultTabController(length: 5, initialIndex: widget.initialTab, child: Scaffold(
      backgroundColor: pale,
      appBar: SafetyDetailHeader(name: name.toString(), subtitle: live ? 'Recent GPS fix • ${stamp(location?['fixAt'])} • ${location?['city'] ?? 'Location unavailable'}' : 'Last GPS fix: ${stamp(location?['fixAt'])}', labels: ['Map & History', 'Safe zones (${safe.length})', 'SOS alerts', 'Sync interval', 'Phone activity']),
      body: busy ? const Center(child: CircularProgressIndicator()) : TabBarView(children: [
        ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          if (error.isNotEmpty) Text(error, style: TextStyle(color: danger)),
          ClipRRect(borderRadius: BorderRadius.circular(24), child: SizedBox(height: 190, child: Stack(children: [MiniMap(key: ValueKey('route-$playing-$playIndex-${playing ? '' : current}'), points: shown, fresh: !playing && live, zones: safe), Positioned(top: 12, left: 12, right: 12, child: Align(alignment: Alignment.centerLeft, child: pill('$name • ${playing ? 'Recorded route' : location?['city'] ?? 'Location unavailable'}'))), Positioned(bottom: 12, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999)), child: Text('${safe.length} safe zones • ${latest?['accuracy'] != null ? 'GPS ±${latest!['accuracy']}m' : 'GPS accuracy unavailable'}', style: TextStyle(fontSize: 11.5, color: muted))))]))),
          const SizedBox(height: 14), Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(0,48)), onPressed: pts.isEmpty ? null : () => togglePlayback(pts.length), icon: Icon(playing ? Icons.stop : Icons.play_arrow), label: Text(playing ? 'Stop' : 'Play route history')), Text('Historical GPS • gaps may be missing', style: TextStyle(fontSize: 13, color: muted))]),
          Slider(value: pts.isEmpty ? 0 : playIndex.clamp(0,pts.length-1).toDouble(), max: pts.length <= 1 ? 1 : pts.length-1.0, onChanged: pts.isEmpty ? null : (v) { playback?.cancel(); setState(() { playing=true; playIndex=v.toInt(); }); }),
          Text(ordered.isEmpty ? 'No history' : 'Historical GPS • ${stamp(ordered[playIndex.clamp(0,ordered.length-1)]['fixAt'])}', style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 14), panel([draftTitle('Recent fixes'), const SizedBox(height: 10), if (ordered.isEmpty) Text('No recorded fixes yet', style: TextStyle(color: muted)), for(final h in ordered.reversed) draftHistoryRow(stamp(h['fixAt']), h['city']?.toString() ?? 'Recorded location', '${h['accuracy'] != null ? '±${h['accuracy']} m' : 'Accuracy unavailable'} • ${h['battery'] ?? '--'}% battery')]),
          const SizedBox(height: 14), Text('Route playback joins recorded points and may have gaps. Old reports are not live GPS.', style: TextStyle(fontSize: 13, color: muted, height: 1.45)),
        ]),
        ListView(padding: const EdgeInsets.fromLTRB(16,4,16,24), children: [
          FilledButton.icon(onPressed: addZone, icon: const Icon(Icons.add), label: const Text('Add Zone')), const SizedBox(height: 14),
          if(safe.isEmpty) panel([draftTitle('No safe zones yet')]),
          for(final z in safe) Padding(padding: const EdgeInsets.only(bottom: 14), child: panel([
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [draftTitle(z['name'].toString()), const SizedBox(height: 2), Text('Radius ${z['radius']} m', style: TextStyle(fontSize: 13,color: muted))])), pill(z['inside'] == null ? 'Waiting' : z['inside'] == true ? 'Inside' : 'Outside', color: z['inside'] == true ? accent : onAmber)]),
            const SizedBox(height: 12), Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [Text('Entry and exit alerts', style: TextStyle(fontSize: 13,color: muted)), TextButton(onPressed: () => addZone(z), child: const Text('Edit')), TextButton(onPressed: () => deleteZone(z), style: TextButton.styleFrom(foregroundColor: danger), child: const Text('Delete'))]),
          ])),
          panel([draftTitle('Recent zone alerts'), for(final e in zones['events'] as List? ?? []) draftHistoryRow(stamp(e['fixAt']), '${e['entered'] == true ? 'Entered' : 'Left'} ${e['zoneName']}', 'Recorded zone event')]),
          const SizedBox(height: 14), Text('Alerts need two fresh reports. Up to 10 zones per device.', style: TextStyle(fontSize: 13,color: muted)),
        ]),
        ListView(padding: const EdgeInsets.fromLTRB(16,4,16,24), children: [
          if(sos.isEmpty) panel([draftTitle('Emergency SOS history'), const SizedBox(height: 10), Text('No SOS reports received', style: TextStyle(fontSize: 13,color: muted))]),
          for(final h in sos) Padding(padding: const EdgeInsets.only(bottom: 14), child: panel([Text('EMERGENCY SOS HISTORY', style: TextStyle(fontSize: 11,color: muted,fontWeight: FontWeight.w700,letterSpacing: .8)), const SizedBox(height: 4), draftTitle('SOS Button Pressed, ${stamp(h['receivedAt'])}'), const SizedBox(height: 14), Text('$name reported an emergency from ${h['city'] ?? 'an unknown location'}.', style: TextStyle(fontSize: 13,height: 1.45,color: muted))])),
          const SizedBox(height: 14), Text('Recorded device alerts. No emergency calls or acknowledgement workflow.', style: TextStyle(fontSize: 13,height: 1.45,color: muted)),
        ]),
        ListView(padding: const EdgeInsets.fromLTRB(16,4,16,24), children: [
          panel([draftTitle('Report interval'), label('Location reports'), DropdownButtonFormField<int>(initialValue: interval, items: [for(final v in [30,60,120,300,600,1800,3600]) DropdownMenuItem(value: v, child: Text(v == 30 ? 'Every 30 seconds' : v == 3600 ? 'Every 1 hour' : 'Every ${v ~/ 60} ${v == 60 ? 'minute' : 'minutes'}'))], onChanged: (v) => setState(() => interval=v!)), const SizedBox(height: 14), FilledButton(onPressed: saveInterval, child: const Text('Save Interval Setting')), const SizedBox(height: 14), Text("Controls how often $name's phone sends reports. Applies on its next successful report. Long intervals can miss short zone visits. GPS may remain active, so battery savings are not guaranteed.", style: TextStyle(fontSize: 13,height: 1.45,color: muted)), if(error.isNotEmpty) Text(error, style: TextStyle(color: danger))]),
          const SizedBox(height: 14), panel([draftTitle('Safety alerts'), label('Low battery threshold'), DropdownButtonFormField<int>(initialValue: batteryThreshold, items: [for(final v in [0,10,15,20,30]) DropdownMenuItem(value: v, child: Text(v==0 ? 'Off' : '$v%'))], onChanged: (v)=>setState(()=>batteryThreshold=v!)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Speed alert'), value: speedLimit>0, onChanged: (v)=>setState(()=>speedLimit=v ? 80 : 0)), if(speedLimit>0) Column(children:[Text('Alert above $speedLimit km/h'),Slider(min:10,max:200,divisions:38,value:speedLimit.toDouble(),onChanged:(v)=>setState(()=>speedLimit=v.round()))]), for(final a in speedAlerts.take(5)) draftHistoryRow(stamp(a['reportedAt']), a['title']?.toString() ?? 'Speed alert', '${a['body']}'), if(speedAlerts.isEmpty) Text('No recorded speed alerts yet.',style:TextStyle(fontSize:13,color:muted)), const SizedBox(height:14), FilledButton(onPressed:saveAlerts,child:const Text('Save Alert Settings')), const SizedBox(height:14), Text('Tap Save Alert Settings to apply. Requires two fresh accurate GPS speed reports. Open-app checks every 30 seconds; background checks 15 minutes or later. Not instant push. GPS is an estimate.',style:TextStyle(fontSize:13,height:1.45,color:muted))]),
          const SizedBox(height:14), panel([draftTitle('Offline reports'), const SizedBox(height:8), Text('Updated child app stores up to 2,880 encrypted reports while offline, then uploads them in order when the connection returns. Original GPS times stay unchanged. Old reports are not live location; tracking stops if Android force-stops the app.',style:TextStyle(fontSize:13,height:1.45,color:muted))]),
        ]),
        ActivityTab(deviceId:widget.child['deviceId']),
      ]),
    ));
  }
}
'''
# Guard the byte-identical non-UI methods against unintended change.
for start,end in [('  Future<void> refresh()', '  Future<void> login()'), ('  Future<void> login()', '  Future<void> resetPassword()'), ('  Future<void> load()', '  Future<void> saveAlerts()'), ('  Future<void> saveAlerts()', '  @override\n  Widget build(BuildContext context) {')]:
    base=original[original.index(start):original.index(end,original.index(start))]
    assert base in s, 'non-UI method changed: '+start
p.write_text(s)
# Style-only changes in Phone activity preserve all calculations and API calls.
p=Path('lib/activity.dart'); a=p.read_text()
a=a.replace("import 'main.dart' show ParentTheme, surface;", "import 'main.dart' show ParentTheme, surface, accent, tonal, edge;")
a=a.replace('const _green = Color(0xff2f6b5e);','Color get _green => accent;')
a=a.replace('padding: EdgeInsets.all(14)','padding: EdgeInsets.all(18)').replace('padding: EdgeInsets.all(12)','padding: EdgeInsets.fromLTRB(16,4,16,24)')
a=a.replace('BorderRadius.circular(16)','BorderRadius.circular(24)').replace('BorderRadius.circular(12)','BorderRadius.circular(16)')
a=a.replace('color: surface,\n      borderRadius:', 'color: surface,\n      border: Border.all(color: edge),\n      borderRadius:')
a=a.replace('fontSize: 13,\n              fontWeight: FontWeight.w800,','fontFamily: \'Space Grotesk\',\n              fontSize: 19,\n              fontWeight: FontWeight.w700,')
a=a.replace('_green.withValues(alpha: .08)', 'tonal').replace("label: Text('$r days', style: TextStyle(fontSize: 11)),", "label: Text('$r days', style: TextStyle(fontSize: 14)),\n                    selectedColor: _green, showCheckmark: false,\n                    labelStyle: TextStyle(color: range == r ? (ParentTheme.dark.value ? const Color(0xff06201a) : Colors.white) : _ink),\n                    shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),")
a=a.replace("Text('$r days', style: TextStyle(fontSize: 14))", "Text('$r days')")
a=a.replace('color: d[\'day\'] == selected ? _ink : _green', "color: d['day'] == selected ? _green : _green.withValues(alpha: .22)")
a=a.replace('BorderRadius.circular(4)', 'BorderRadius.circular(7)')
a=a.replace('fontSize: 10, color: _muted','fontSize: 13, color: _muted').replace('fontSize: 12','fontSize: 13')
p.write_text(a)
# Update dialog uses the same app theme, with no downloader or install logic changes.
p=Path('lib/update/app_update.dart'); a=p.read_text(); a=a.replace('const dim = Color(0xFF8A93A6);','final dim = Theme.of(context).colorScheme.onSurfaceVariant;').replace('backgroundColor: const Color(0xFF151A24),','backgroundColor: Theme.of(context).colorScheme.surface,').replace('BorderRadius.circular(16)','BorderRadius.circular(24)').replace('const TextStyle(color: dim', 'TextStyle(color: dim')
p.write_text(a)
p=Path('pubspec.yaml'); p.write_text(p.read_text().replace('version: 1.4.9+14','version: 1.4.10+15'))
p=Path('lib/live/bug_report.dart'); p.parent.mkdir(parents=True,exist_ok=True); p.write_text("// Release identity shared with the visible Settings version. No report collection.\nconst appVersion = '1.4.10';\nconst appBuildNumber = 15;\n")
assert 'version: 1.4.10+15' in Path('pubspec.yaml').read_text()
assert "const appVersion = '1.4.10';" in p.read_text()
print('Parent UI rebuilt. All guarded non-UI methods unchanged; versions match 1.4.10+15.')
