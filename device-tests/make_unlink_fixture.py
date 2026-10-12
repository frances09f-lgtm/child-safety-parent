from pathlib import Path
exec(Path('device-tests/make_fixture.py').read_text())
p=Path('lib/runtime_fixture.dart');s=p.read_text();a=s.index('  Future<void> _restore()');b=s.index('\n  @override\n  void dispose()',a);s=s[:a]+"  Future<void> _restore() async {FamilyApi.email='fixture@example.invalid';setState((){ready=true;signed=true;section=0;children=sampleChildren;});}\n"+s[b:];p.write_text(s)
p=Path('lib/api.dart');s=p.read_text().replace("    if(path.startsWith('/api/zones/'))", "    if(path=='/api/devices/fixture_device'&&method=='DELETE')return {'status':'unlinked'};\n    if(path.startsWith('/api/zones/'))");p.write_text(s)
