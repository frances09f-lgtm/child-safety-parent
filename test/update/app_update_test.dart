import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:child_safety_parent/update/app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('compareVersions', () {
    expect(compareVersions('1.0.20', '1.0.19'), greaterThan(0));
    expect(compareVersions('v1.0.20', '1.0.20'), 0);
    expect(compareVersions('22', '1.0.22'), greaterThan(0)); // old tag shape
  });
  test('fetchLatest reads the public feed and compares', () async {
    const body =
        '{"parent":{"version":"1.4.6","notes":"in-app updates","apk":"https://x/P.apk"},'
        '"client":{"version":"1.0.15","notes":"","apk":"https://x/C.apk"}}';
    final c = UpdateChecker(
      client: MockClient((_) async => http.Response(body, 200)),
      currentVersion: () async => '1.4.5',
    );
    final info = await c.fetchLatest();
    expect(info!.version, '1.4.6');
    expect(info.apkUrl, endsWith('P.apk'));
    final same = UpdateChecker(
      client: MockClient((_) async => http.Response(body, 200)),
      currentVersion: () async => '1.4.6',
    );
    expect(await same.fetchLatest(), isNull);
  });
  test('autoCheck stamps failures and respects the interval', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final c = UpdateChecker(
      client: MockClient((_) async {
        calls++;
        return http.Response('x', 500);
      }),
      currentVersion: () async => '1.0.19',
    );
    expect(await c.autoCheck(), isNull);
    expect(await c.autoCheck(), isNull);
    expect(calls, 1);
  });
}
