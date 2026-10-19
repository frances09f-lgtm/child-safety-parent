import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:child_safety_parent/main.dart';
import 'package:child_safety_parent/api.dart';

Map<String, dynamic> report(String device, int minute) => {
  'deviceId': device,
  'hasFix': true,
  'fixAt': '2026-01-01T08:${minute.toString().padLeft(2, '0')}:00Z',
  'latitude': 16.0 + minute,
  'longitude': 74.0,
};
void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    FamilyApi.server = 'https://example.invalid';
  });
  testWidgets(
    'detail refreshes by device; pauses, resumes, and cancels timers',
    (tester) async {
      int count = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: ChildDetail(
                child: {
                  'deviceId': 'a',
                  'childName': 'Test',
                  'latest': report('a', 0),
                },
                initialTab: 3,
              ),
            ),
          );
          await tester.pump();
          await tester.pump();
          dynamic state = tester.state(find.byType(ChildDetail));
          expect(state.lastFix['latitude'], 17.0);
          expect(count, 1);
          await tester.pump(const Duration(seconds: 30));
          await tester.pump();
          expect(count, 2);
          expect(state.lastFix['latitude'], 18.0);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump(const Duration(seconds: 60));
          expect(count, 2);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          await tester.pump();
          expect(count, 3);
          expect(state.lastFix['latitude'], 19.0);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 60));
          expect(count, 3);
        },
        () => MockClient((req) async {
          if (req.url.host == 'securetoken.googleapis.com')
            return http.Response(
              jsonEncode({
                'id_token': 'fake',
                'refresh_token': 'fake',
                'expires_in': '3600',
              }),
              200,
            );
          final p = req.url.path;
          if (p.contains('/latest/')) {
            count++;
            return http.Response(jsonEncode(report('a', count)), 200);
          }
          if (p.contains('/history/'))
            return http.Response(jsonEncode([report('a', count)]), 200);
          return http.Response('{}', 200);
        }),
      );
    },
  );
  testWidgets('old child response cannot overwrite new child', (tester) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(
      () async {
        Widget detail(String id) => MaterialApp(
          home: ChildDetail(
            key: const ValueKey('detail'),
            child: {'deviceId': id, 'childName': id},
            initialTab: 3,
          ),
        );
        await tester.pumpWidget(detail('a'));
        await tester.pump();
        await tester.pumpWidget(detail('b'));
        await tester.pump();
        await tester.pump();
        dynamic state = tester.state(find.byType(ChildDetail));
        expect(state.lastFix['deviceId'], 'b');
        pending.complete(http.Response(jsonEncode(report('a', 9)), 200));
        await tester.pump();
        await tester.pump();
        expect(state.lastFix['deviceId'], 'b');
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((req) async {
        if (req.url.host == 'securetoken.googleapis.com')
          return http.Response(
            jsonEncode({
              'id_token': 'fake',
              'refresh_token': 'fake',
              'expires_in': '3600',
            }),
            200,
          );
        if (req.url.path.endsWith('/latest/a')) return pending.future;
        if (req.url.path.contains('/latest/'))
          return http.Response(jsonEncode(report('b', 1)), 200);
        if (req.url.path.contains('/history/')) return http.Response('[]', 200);
        return http.Response('{}', 200);
      }),
    );
  });
}
