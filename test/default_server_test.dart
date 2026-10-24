import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:child_safety_parent/api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('default server is a valid HTTPS address', () {
    final uri = Uri.parse(FamilyApi.defaultServer);
    expect(uri.scheme, 'https');
    expect(uri.host, isNotEmpty);
    expect(FamilyApi.defaultServer.endsWith('/'), isFalse);
  });
  test('restore falls back to the default server when none is saved', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await FamilyApi.restore();
    expect(FamilyApi.server, FamilyApi.defaultServer);
  });
  test('restore keeps a server the user saved', () async {
    FlutterSecureStorage.setMockInitialValues({
      'server': 'https://custom.example.invalid',
    });
    await FamilyApi.restore();
    expect(FamilyApi.server, 'https://custom.example.invalid');
  });
}
