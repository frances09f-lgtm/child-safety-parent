import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:child_safety_parent/main.dart';
import 'package:child_safety_parent/pally.dart';
import 'package:child_safety_parent/live/bug_report.dart';
void main() {
 test('release version matches in both files',(){ expect(appVersion,'1.4.10'); expect(appBuildNumber,15);expect(File('pubspec.yaml').readAsStringSync(),contains('version: $appVersion+$appBuildNumber')); });
 for(final dark in [false,true]) { for(final width in [320.0,390.0]) {
 testWidgets('draft header and solid dock $dark $width',(tester)async {
  ParentTheme.dark.value=dark;
  tester.view.physicalSize=Size(width,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:Scaffold(appBar:const SafetyHeader(title:'Your Family'),bottomNavigationBar:SafetyDock(index:0,onTap:(_){},items:const [SafetyDockItem(Icons.phone_android,'Children'),SafetyDockItem(Icons.settings,'Settings')]),body:const SizedBox())));
  expect(find.text('Your Family'),findsOneWidget); expect(find.text('Children'),findsOneWidget); expect(tester.takeException(),isNull);
 });
 testWidgets('five pill tabs navigate $dark $width',(tester)async {
  ParentTheme.dark.value=dark;tester.view.physicalSize=Size(width,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const MaterialApp(home:DefaultTabController(length:5,child:Scaffold(appBar:SafetyDetailHeader(name:'Aarav',subtitle:'Last GPS fix: 9:42 AM',labels:['Map & History','Safe zones (2)','SOS alerts','Sync interval','Phone activity']),body:TabBarView(children:[Text('map body'),Text('zone body'),Text('sos body'),Text('sync body'),Text('activity body')])))));
  await tester.ensureVisible(find.text('Safe zones (2)'));await tester.pumpAndSettle();
  await tester.tap(find.text('Safe zones (2)'));await tester.pumpAndSettle();expect(find.text('zone body'),findsOneWidget); expect(tester.takeException(),isNull);
 });
 }}
}
