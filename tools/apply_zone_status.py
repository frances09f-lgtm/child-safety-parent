import sys
p='lib/main.dart'
s=open(p,encoding='utf-8').read()
OLD="                  const SizedBox(height: 10),\n                  Container(\n                    width: double.infinity,\n                    padding: const EdgeInsets.symmetric(\n                      horizontal: 10,\n                      vertical: 8,\n                    ),\n                    decoration: BoxDecoration(\n                      color: events.isEmpty ? tonal : amber,\n                      borderRadius: BorderRadius.circular(14),\n                    ),\n                    child: Text(\n                      events.isEmpty\n                          ? 'No zone alerts yet'\n                          : 'Zone Alert: ${events.first['entered'] == true ? 'Entered' : 'Left'} ${events.first['zoneName']} \u2022 ${stamp(events.first['fixAt'])}',\n                      style: TextStyle(\n                        fontSize: 12,\n                        fontWeight: FontWeight.w600,\n                        color: events.isEmpty ? muted : onAmber,\n                      ),\n                    ),\n                  ),"
NEW="                  Builder(\n                    builder: (_) {\n                      final zs = zoneStatus(child['zonesData']);\n                      if (zs == null) return const SizedBox.shrink();\n                      return Padding(\n                        padding: const EdgeInsets.only(top: 10),\n                        child: Container(\n                          width: double.infinity,\n                          padding: const EdgeInsets.symmetric(\n                            horizontal: 10,\n                            vertical: 8,\n                          ),\n                          decoration: BoxDecoration(\n                            color: zs.recent ? amber : tonal,\n                            borderRadius: BorderRadius.circular(14),\n                          ),\n                          child: Text(\n                            zs.text,\n                            style: TextStyle(\n                              fontSize: 12,\n                              fontWeight: FontWeight.w600,\n                              color: zs.recent ? onAmber : muted,\n                            ),\n                          ),\n                        ),\n                      );\n                    },\n                  ),"
LINE="    final events = child['zonesData']?['events'] as List? ?? [];\n"
assert s.count(OLD)==1, 'old block'
assert s.count(LINE)==1, 'events line'
s=s.replace(OLD,NEW).replace(LINE,'')
IMP="import 'history_today.dart';"
assert s.count(IMP)==1
s=s.replace(IMP,IMP+"\nimport 'zone_status.dart';")
open(p,'w',encoding='utf-8').write(s)
print('patched')
