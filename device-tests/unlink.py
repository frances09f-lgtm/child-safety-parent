import uiautomator2 as u,time,os
D=u.connect();os.makedirs('device-results',exist_ok=True);D.app_start('com.childsafety.parent');time.sleep(25)
for _ in range(3):
 if D(text="Pixel Launcher isn't responding").exists and D(text='Close app').exists:D(text='Close app').click();time.sleep(2)
 else:break
D.screenshot('device-results/unlink-before.png');open('device-results/unlink-before.xml','w').write(D.dump_hierarchy())
if not D(description='Remove device').exists:D.swipe_ext('up',scale=.5);time.sleep(2)
D(description='Remove device').click();time.sleep(2);D.screenshot('device-results/unlink-confirm.png');assert D(descriptionContains='Stored history is kept').exists or D(textContains='Stored history is kept').exists
D(text='Cancel').click();assert D(descriptionContains='Sample child').exists
D(description='Remove device').click();time.sleep(1);D(text='Remove device').click();time.sleep(3);D.screenshot('device-results/unlink-result.png');assert not D(descriptionContains='Sample child').exists
