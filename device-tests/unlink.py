import uiautomator2 as u,time,os
D=u.connect();os.makedirs('device-results',exist_ok=True);D.app_start('com.childsafety.parent');time.sleep(25)
if D(text='Wait').exists:D(text='Wait').click()
D.screenshot('device-results/unlink-before.png');open('device-results/unlink-before.xml','w').write(D.dump_hierarchy())
if not D(text='Remove device').exists:D.swipe_ext('up',scale=.5);time.sleep(2)
D(text='Remove device').click();time.sleep(2);D.screenshot('device-results/unlink-confirm.png');assert D(textContains='Stored history is kept').exists
D(text='Cancel').click();assert D(text='Sample child').exists
D(text='Remove device').click();time.sleep(1);D(text='Remove device').click();time.sleep(3);D.screenshot('device-results/unlink-result.png');assert not D(text='Sample child').exists
