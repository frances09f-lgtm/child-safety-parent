import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:child_safety_parent/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'DELETE serializes token JSON; bodyless DELETE remains bodyless',
    () async {
      FamilyApi.server = 'https://example.invalid';
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          await FamilyApi.request(
            '/api/alerts/token',
            method: 'DELETE',
            data: {'token': 'synthetic-push-token'},
          );
          await FamilyApi.request('/api/zones/a/1', method: 'DELETE');
        },
        () => MockClient((request) async {
          if (request.url.host == 'securetoken.googleapis.com') {
            return http.Response(
              jsonEncode({
                'id_token': 'synthetic-token',
                'refresh_token': 'synthetic-refresh',
                'expires_in': '3600',
              }),
              200,
            );
          }
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );
      expect(requests[0].method, 'DELETE');
      expect(jsonDecode(requests[0].body), {'token': 'synthetic-push-token'});
      expect(requests[0].headers['Content-Type'], 'application/json');
      expect(requests[1].body, isEmpty);
    },
  );
}
