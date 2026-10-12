import uiautomator2 as u,time,os
D=u.connect();os.makedirs('device-results',exist_ok=True);D.app_start('com.childsafety.parent');time.sleep(30)
if D(text='Wait').exists:D(text='Wait').click()
D.open_notification();time.sleep(3);D.screenshot('device-results/speed-notification.png');open('device-results/speed-notification.xml','w').write(D.dump_hierarchy())
assert D(textContains='exceeded speed limit').exists
D(textContains='exceeded speed limit').click();time.sleep(5);D.screenshot('device-results/speed-settings.png');open('device-results/speed-settings.xml','w').write(D.dump_hierarchy())
