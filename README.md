# Child Safety Parent

Parent companion to Child Safety Tracker. Shows every child phone paired to the same parent account, with each phone's last received location, report age, battery, SOS status and safe-zone alerts.

Tap a child to open recorded route playback, report history, safe zones and reporting intervals. Sign in with the same parent account used in the child app. Enter the HTTPS backend and Firebase public application key at runtime under Server configuration. Passwords are not saved; refresh access stays in encrypted Android storage.

A child phone still needs the Child Safety Tracker app, parent pairing, location/notification permissions and Start tracking. Installation alone does not begin tracking. The parent app does not request the parent's GPS or run child tracking services.

The first version refreshes while open. FCM push alerts, low-battery/speed alerts and child offline buffering are separate next stages and are not claimed as working here. Old location reports are not live GPS. Route playback joins recorded points and may have gaps. No emergency services are called. Do not use this as the only way to check a child's safety.

Build-only delivery was requested. No new feature test rounds are run; compilation, static checks, signing and visual inspection still apply.
