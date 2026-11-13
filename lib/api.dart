// DriverGuardian mobile — API client (Laravel Sanctum bearer tokens).
// Developed & Powered by Marian Anbu Juwan
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Server address. Set at build time with
///   flutter build apk --dart-define=API_BASE=https://driverguardian.in
/// and changeable from the sign-in screen (⚙).
const String kDefaultServer = String.fromEnvironment('API_BASE', defaultValue: 'https://driverguardian.in');

/// The web app (PWA) is served from <site>/app/, so the site it belongs to is
/// everything before "/app/" — one build works on any domain or sub-folder.
String webServer() {
  final u = Uri.base;
  final m = RegExp(r'^(.*?)/app(/|$)').firstMatch(u.path);
  return '${u.origin}${m?.group(1) ?? ''}';
}

/// Short device label sent at sign-in (shown in the web admin's sessions list).
String deviceLabel() {
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  if (kIsWeb) return ios ? 'iPhone web app' : 'Web app';
  return ios ? 'iOS app' : 'Android app';
}

class ApiException implements Exception {
  final String message;
  final int status;
  final Map<String, dynamic> body;
  ApiException(this.message, this.status, [this.body = const {}]);
  @override
  String toString() => message;
}

class Api {
  Api._();
  static final Api I = Api._();

  String server = kDefaultServer;
  String? token;
  Map<String, dynamic>? user;

  /// Platform admins pick a school to work in (sent as X-School-Id).
  int? schoolId;
  String? schoolName;

  /// Called when the server says the session is no longer valid.
  void Function()? onUnauthorized;

  String get base => '${server.replaceAll(RegExp(r'/+$'), '')}/api/v1';
  String get role => (user?['role'] ?? '') as String;
  bool get isAdmin => role == 'school_admin' || role == 'super_admin';
  bool get isSuper => role == 'super_admin';

  Future<void> setSchool(int? id, [String? name]) async {
    schoolId = id;
    schoolName = name;
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove('school_id');
      await p.remove('school_name');
    } else {
      await p.setInt('school_id', id);
      await p.setString('school_name', name ?? '');
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    server = kIsWeb ? webServer() : (p.getString('server') ?? kDefaultServer);
    token = p.getString('token');
    schoolId = p.getInt('school_id');
    schoolName = p.getString('school_name');
    final u = p.getString('user');
    if (u != null) {
      try {
        user = jsonDecode(u) as Map<String, dynamic>;
      } catch (_) {}
    }
  }

  Future<void> saveServer(String s) async {
    server = s.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString('server', server);
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    if (token == null) {
      await p.remove('token');
      await p.remove('user');
    } else {
      await p.setString('token', token!);
      await p.setString('user', jsonEncode(user));
    }
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (schoolId != null && isSuper) 'X-School-Id': '$schoolId',
      };

  Future<Map<String, dynamic>> _send(String method, String path, {Map<String, dynamic>? body, Map<String, String>? query}) async {
    var uri = Uri.parse('$base$path');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);
    http.Response res;
    try {
      final f = switch (method) {
        'GET' => http.get(uri, headers: _headers),
        'PUT' => http.put(uri, headers: _headers, body: jsonEncode(body ?? {})),
        'DELETE' => http.delete(uri, headers: _headers),
        _ => http.post(uri, headers: _headers, body: jsonEncode(body ?? {})),
      };
      res = await f.timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.', 0);
    } on http.ClientException catch (e) {
      throw ApiException(_netMessage(e), 0);
    }
    Map<String, dynamic> data = {};
    if (res.body.isNotEmpty) {
      try {
        final d = jsonDecode(res.body);
        if (d is Map<String, dynamic>) data = d;
      } catch (_) {
        if (res.statusCode >= 400) throw ApiException('Unexpected server response (${res.statusCode}). Check the server address.', res.statusCode);
      }
    }
    if (res.statusCode == 401 && token != null) {
      await logoutLocal();
      onUnauthorized?.call();
      throw ApiException('Your session has ended. Please sign in again.', 401, data);
    }
    if (res.statusCode >= 400) {
      String msg = (data['message'] ?? data['error'] ?? 'Request failed (${res.statusCode})').toString();
      final errs = data['errors'];
      if (errs is Map && errs.isNotEmpty) {
        final first = errs.values.first;
        if (first is List && first.isNotEmpty) msg = first.first.toString();
      }
      throw ApiException(msg, res.statusCode, data);
    }
    return data;
  }

  Future<Map<String, dynamic>> get(String path, [Map<String, String>? query]) => _send('GET', path, query: query);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body: body);
  Future<Map<String, dynamic>> put(String path, [Map<String, dynamic>? body]) => _send('PUT', path, body: body);

  /// No network, DNS failure, blocked by the browser (CORS) … — one friendly message.
  String _netMessage(http.ClientException e) {
    final m = e.message.toLowerCase();
    if (m.contains('socket') || m.contains('host lookup') || m.contains('network') || m.contains('failed to fetch') || m.contains('xmlhttprequest')) {
      return 'No internet connection or the server cannot be reached. Please check your network.';
    }
    return 'Could not reach the server (${e.message}).';
  }

  /// Multipart POST (form fields + one optional file), e.g. an incident with a photo.
  /// The file goes as bytes ([fileBytes] + [fileName]) — works on phones and in the browser.
  Future<Map<String, dynamic>> postMultipart(String path, Map<String, String> fields, {String? fileField, List<int>? fileBytes, String? fileName}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$base$path'))
      ..headers.addAll({'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token', if (schoolId != null && isSuper) 'X-School-Id': '$schoolId'})
      ..fields.addAll(fields);
    if (fileField != null && fileBytes != null) req.files.add(http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName ?? 'photo.jpg'));
    http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
    } on TimeoutException {
      throw ApiException('Upload took too long. Please try again.', 0);
    } on http.ClientException catch (e) {
      throw ApiException(_netMessage(e), 0);
    }
    Map<String, dynamic> data = {};
    try { final d = jsonDecode(res.body); if (d is Map<String, dynamic>) data = d; } catch (_) {}
    if (res.statusCode == 401 && token != null) { await logoutLocal(); onUnauthorized?.call(); throw ApiException('Your session has ended. Please sign in again.', 401, data); }
    if (res.statusCode >= 400) {
      String msg = (data['message'] ?? 'Request failed (${res.statusCode})').toString();
      final errs = data['errors'];
      if (errs is Map && errs.isNotEmpty && errs.values.first is List && (errs.values.first as List).isNotEmpty) msg = (errs.values.first as List).first.toString();
      throw ApiException(msg, res.statusCode, data);
    }
    return data;
  }

  Future<void> login(String login, String password, String schoolCode) async {
    final d = await post('/auth/login', {
      'login': login.trim(),
      'password': password,
      'school_code': schoolCode.trim(),
      'device_name': deviceLabel(),
    });
    token = d['token'] as String;
    user = (d['user'] as Map).cast<String, dynamic>();
    await _persist();
  }

  Future<void> refreshMe() async {
    final d = await get('/me');
    user = (d['user'] as Map).cast<String, dynamic>();
    await _persist();
  }

  Future<void> logout({String? pushToken}) async {
    try {
      await post('/auth/logout', {if (pushToken != null) 'push_token': pushToken});
    } catch (_) {}
    await logoutLocal();
  }

  Future<void> logoutLocal() async {
    token = null;
    user = null;
    await setSchool(null);
    await _persist();
  }
}
