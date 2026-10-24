import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FamilyApi {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  // Public Firebase Web API key for project app-testing-2cdba: public client
  // configuration, not a secret. Pre-filled so sign-in never asks for it;
  // the field stays editable for project moves.
  static const defaultKey = 'AIzaSyCh-l1is7a-wMWZGhHWUnh9rV0BkdvADbk';
  // Deployed HTTPS backend for this project. Documented in the README of
  // frances09f-lgtm/child-safety-client ("Values you need"). Pre-filled so
  // sign-in never opens with an empty address; the field stays editable.
  static const defaultServer = 'https://child-safety-api-t76a.onrender.com';
  static String server = defaultServer,
      key = defaultKey,
      email = '',
      _token = '',
      _refresh = '';
  static bool _remember = true;
  static DateTime _expires = DateTime(2000);
  static Future<bool> restore() async {
    final savedServer = (await storage.read(key: 'server') ?? '').trim();
    server = savedServer.isEmpty ? defaultServer : savedServer;
    key = await storage.read(key: 'key') ?? defaultKey;
    email = await storage.read(key: 'email') ?? '';
    final until = DateTime.tryParse(
      await storage.read(key: 'rememberUntil') ?? '',
    );
    if (until == null || DateTime.now().isAfter(until)) {
      await logout();
      return false;
    }
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
    String password, {
    bool remember = true,
  }) async {
    final uri = Uri.parse(endpoint.trim());
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty)
      throw Exception('Use an HTTPS server address.');
    _remember = remember;
    FamilyApi.email = email.trim();
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
    if (_remember) {
      await storage.write(key: 'email', value: FamilyApi.email);
      await storage.write(
        key: 'rememberUntil',
        value: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      );
      await storage.write(key: 'refresh', value: _refresh);
    } else {
      await storage.delete(key: 'refresh');
      await storage.delete(key: 'rememberUntil');
    }
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
    if (_remember) await storage.write(key: 'refresh', value: _refresh);
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
      r = await http
          .delete(
            uri,
            headers: headers,
            body: data == null ? null : jsonEncode(data),
          )
          .timeout(const Duration(seconds: 30));
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

  static Future<void> resetPassword(String address, String firebase) async {
    if (address.trim().isEmpty || firebase.trim().isEmpty)
      throw Exception(
        'Enter your email and Firebase app key in Server configuration.',
      );
    final r = await http
        .post(
          Uri.https(
            'identitytoolkit.googleapis.com',
            '/v1/accounts:sendOobCode',
            {'key': firebase.trim()},
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'requestType': 'PASSWORD_RESET',
            'email': address.trim(),
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200)
      throw Exception(
        'Could not request reset email. Check email and app configuration.',
      );
  }

  static Future<void> changePassword(String current, String next) async {
    final savedServer = server, savedKey = key, savedEmail = email;
    final remembered = _remember;
    await login(
      savedServer,
      savedKey,
      savedEmail,
      current,
      remember: remembered,
    );
    final r = await http
        .post(
          Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:update', {
            'key': key,
          }),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idToken': _token,
            'password': next,
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200)
      throw Exception(
        'Password was not changed. Check your current password and try again.',
      );
    final data = jsonDecode(r.body);
    _token = data['idToken'];
    _refresh = data['refreshToken'];
    _expires = DateTime.now().add(
      Duration(seconds: int.parse(data['expiresIn'].toString()) - 60),
    );
    if (_remember) await storage.write(key: 'refresh', value: _refresh);
  }

  static Future<void> logout() async {
    // Keep one-time server/public app configuration across logout/expiry.
    await storage.delete(key: 'refresh');
    await storage.delete(key: 'rememberUntil');
    await storage.delete(key: 'email');
    _token = '';
    _refresh = '';
    email = '';
  }
}
