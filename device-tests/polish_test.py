import uiautomator2 as u,time,json,os
D=u.connect();O='device-results';os.makedirs(O,exist_ok=True);R=[]
def snap(n):D.screenshot(O+'/'+n+'.png');open(O+'/'+n+'.xml','w').write(D.dump_hierarchy())
def click(t):
 x=D(text=t)
 if not x.exists:x=D(description=t)
 if not x.exists:x=D(textContains=t)
 if not x.exists:x=D(descriptionContains=t)
 assert x.exists,'Missing UI:'+t
 x.click();time.sleep(2)
def contains(t):return t in D.dump_hierarchy()
D.app_start('com.childsafety.parent');time.sleep(12);snap('01-light-home');assert contains('Sample child')
click('Settings');snap('02-light-settings')
click('Dark mode');snap('03-dark-settings');R.append({'dark_toggle':True})
D.app_stop('com.childsafety.parent');D.app_start('com.childsafety.parent');time.sleep(8);click('Settings');snap('04-dark-restored')
click('Change Password');snap('05-password-dialog');assert contains('Old Password') or contains('Current password');D.press('back');time.sleep(1)
click('Children');D(descriptionContains='Sample child').click(offset=(0.5,0.1));time.sleep(2);snap('06-dark-child')
click('Safe Zones');snap('07-zones');click('Edit safe zone');snap('08-edit-zone');assert contains('Edit safe zone') and contains('Sample school');D(className='android.widget.EditText',instance=0).set_text('School gate');D(className='android.widget.EditText',instance=1).set_text('450');snap('08a-zone-filled');click('Save zone');snap('08b-zone-saved');assert contains('School gate') and contains('450m')
click('Add Zone');snap('09-add-zone');assert contains('Add safe zone');D.press('back')
R.append({'dialogs_and_zone_edit_visible':True});json.dump(R,open(O+'/report.json','w'),indent=2)
