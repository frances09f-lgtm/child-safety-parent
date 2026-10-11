from pathlib import Path
s=Path('lib/main.dart').read_text()
s=s.replace("import 'activity.dart';", "import 'activity.dart';\nfinal sampleChildren=<Map<String,dynamic>>[{'childName':'Sample child','deviceId':'fixture_device','reportIntervalSeconds':30,'latest':{'hasFix':true,'latitude':18.52,'longitude':73.85,'fixAt':DateTime.now().toUtc().toIso8601String(),'receivedAt':DateTime.now().toUtc().toIso8601String(),'battery':84,'city':'Sample city','accuracy':5,'emergency':false},'zonesData':{'zones':[],'events':[]}}];")
a=s.index('  Future<void> _restore()');b=s.index('\n  @override\n  void dispose()',a)
s=s[:a]+'''  Future<void> _restore() async { FamilyApi.email='fixture@example.invalid';setState((){ready=true;signed=true;section=0;children=sampleChildren;}); }
'''+s[b:]
a=s.index('  Future<void> refresh()');b=s.index('\n  Future<void> login()',a);s=s[:a]+'''  Future<void> refresh() async {}
'''+s[b:]
a=s.index('  Future<void> load()',s.index('class _ChildDetailState'));b=s.index('\n  Future<void> saveAlerts()',a)
s=s[:a]+'''  Future<void> load() async {setState((){busy=false;history=[];zones={'zones':[{'id':1,'name':'Sample school','radius':300,'latitude':18.52,'longitude':73.85,'inside':true}],'events':[]};});}
'''+s[b:]
# Theme must be shared with imported Phone Activity module; import original main alias and delegate.
s=s.replace("import 'activity.dart';", "import 'activity.dart';\nimport 'main.dart' as production;")
a=s.index('class ParentTheme');b=s.index('\nFuture<void> main()',a)
s=s[:a]+'''class ParentTheme {static final dark = production.ParentTheme.dark;static Future<void> load()=>production.ParentTheme.load();static Future<void> set(bool v)=>production.ParentTheme.set(v);}
'''+s[b:]
Path('lib/runtime_fixture.dart').write_text(s)

# Mock zone writes and reads inside isolated APK; no real accounts or server.
a=Path('lib/api.dart').read_text()
pos=a.index('  static Future<dynamic> request(');end=a.index('  static Future<void> resetPassword',pos)
a=a[:pos]+"""  static Map<String,dynamic> fixtureZone={'id':1,'name':'Sample school','radius':300,'latitude':18.52,'longitude':73.85,'inside':true};
  static Future<dynamic> request(String path,{String method='GET',Object? data}) async {
    if(path.startsWith('/api/zones/')){if(method=='PUT'){fixtureZone={...fixtureZone,...Map<String,dynamic>.from(data as Map)};}return {'zones':[fixtureZone],'events':[]};}
    if(path.startsWith('/api/activity/'))return {'days':[],'lastSync':null};
    throw Exception('Only isolated fixture routes are allowed');
  }
"""+a[end:]
Path('lib/api.dart').write_text(a)
# Reload the saved mock zone so the UI asserts actual editing logic.
p=Path('lib/runtime_fixture.dart');v=p.read_text().replace("'zones':[{'id':1,'name':'Sample school','radius':300,'latitude':18.52,'longitude':73.85,'inside':true}]","'zones':[FamilyApi.fixtureZone]");p.write_text(v)

# Notification-only fixture: no owner account, one baseline then a synthetic event.
p=Path('lib/runtime_fixture.dart');v=p.read_text();v=v.replace("Future<void> refresh() async {}", "Future<void> refresh() async {}")
v=v.replace("children=sampleChildren;}); }", "children=sampleChildren;}); await ZoneAlerts.enable(sampleChildren); await ZoneAlerts.consume(sampleChildren.first,[{'id':1,'entered':true,'zoneName':'Sample school','fixAt':'2026-10-12T04:50:00+05:30'}]); }")
p.write_text(v)
