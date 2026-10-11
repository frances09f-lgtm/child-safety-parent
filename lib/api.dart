import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FamilyApi {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static String server = '', key = '', _token = '', _refresh = '';
  static DateTime _expires = DateTime(2000);
  static Future<bool> restore() async {
    server = await storage.read(key: 'server') ?? '';
    key = await storage.read(key: 'key') ?? '';
    _refresh = await storage.read(key: 'refresh') ?? '';
    if (_refresh.isEmpty) return false;
    try {
      await _renew();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> login(
    String endpoint,
    String firebase,
    String email,
    String password,
  ) async {
    final uri = Uri.parse(endpoint.trim());
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty)
      throw Exception('Use an HTTPS server address.');
    server = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    key = firebase.trim();
    final response = await http
        .post(
          Uri.https(
            'identitytoolkit.googleapis.com',
            '/v1/accounts:signInWithPassword',
            {'key': key},
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
            'password': password,
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200)
      throw Exception(
        'Sign-in failed. Check account and server configuration.',
      );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _token = data['idToken'];
    _refresh = data['refreshToken'];
    _expires = DateTime.now().add(
      Duration(seconds: int.parse(data['expiresIn'].toString()) - 60),
    );
    await storage.write(key: 'refresh', value: _refresh);
    await storage.write(key: 'server', value: server);
    await storage.write(key: 'key', value: key);
  }

  static Future<void> _renew() async {
    final response = await http
        .post(
          Uri.https('securetoken.googleapis.com', '/v1/token', {'key': key}),
          body: {'grant_type': 'refresh_token', 'refresh_token': _refresh},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw Exception('Sign in again.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _token = data['id_token'];
    _refresh = data['refresh_token'];
    _expires = DateTime.now().add(
      Duration(seconds: int.parse(data['expires_in'].toString()) - 60),
    );
    await storage.write(key: 'refresh', value: _refresh);
  }

  static Future<dynamic> request(
    String path, {
    String method = 'GET',
    Object? data,
  }) async {
    if (DateTime.now().isAfter(_expires)) await _renew();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
    final uri = Uri.parse('$server$path');
    http.Response r;
    if (method == 'POST') {
      r = await http.post(uri, headers: headers, body: jsonEncode(data));
    } else if (method == 'PUT') {
      r = await http.put(uri, headers: headers, body: jsonEncode(data));
    } else if (method == 'DELETE') {
      r = await http.delete(uri, headers: headers);
    } else {
      r = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 60));
    }
    if (r.statusCode == 404) return null;
    if (r.statusCode < 200 || r.statusCode >= 300)
      throw Exception('Server request failed (${r.statusCode}).');
    return jsonDecode(r.body);
  }

  static Future<void> logout() async {
    await storage.deleteAll();
    _token = '';
    _refresh = '';
  }
}
