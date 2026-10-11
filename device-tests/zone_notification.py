import uiautomator2 as u,time,os,json
D=u.connect();os.makedirs('device-results',exist_ok=True)
def snap(n):D.screenshot('device-results/'+n+'.png');open('device-results/'+n+'.xml','w').write(D.dump_hierarchy())
D.app_start('com.childsafety.parent');time.sleep(12);open('device-results/logcat.txt','w').write(D.shell('logcat -d -s flutter AndroidRuntime').output);snap('01-home')
D.open_notification();time.sleep(2);snap('02-zone-notification');x=D(textContains='Sample child entered');assert x.exists;x.click();time.sleep(4);snap('03-zone-tap');assert 'Safe Zones (1)' in D.dump_hierarchy()
D.press('back');D(descriptionContains='Settings').click();time.sleep(2);snap('04-zone-settings')
json.dump({'synthetic_local_notification':True,'tap_child_dashboard':True},open('device-results/report.json','w'))
