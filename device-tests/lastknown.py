import uiautomator2 as u,time,os
D=u.connect();os.makedirs('device-results',exist_ok=True);D.app_start('com.childsafety.parent');time.sleep(25);D.screenshot('device-results/last-known.png');open('device-results/last-known.xml','w').write(D.dump_hierarchy());assert 'Last GPS fix:' in D.dump_hierarchy()
