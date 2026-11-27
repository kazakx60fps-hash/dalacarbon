// DalaCarbon AI серверінің JSON API клиенті (/api/v1).
// Токен Android Keystore-да (flutter_secure_storage) сақталады; «Мені есте сақта» өшік болса — тек жадта.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  ApiException(this.message, {this.status = 0, this.errors = const {}});

  final String message;
  final int status;
  final Map<String, String> errors; // өріс → қате мәтіні (сайттағымен бірдей)

  @override
  String toString() => message;
}

class Api {
  Api._();

  static final instance = Api._();
  static const _storage = FlutterSecureStorage();

  /// Эмулятордан компьютердегі Flask серверіне: 10.0.2.2 = компьютердің 127.0.0.1-і.
  /// Нақты телефонда — компьютердің Wi-Fi IP-і (Баптаулар → Сервер мекенжайы).
  static const defaultBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:5000');

  String base = defaultBase;
  String? token;

  Future<void> restore() async {
    base = await _storage.read(key: 'dc_base') ?? defaultBase;
    token = await _storage.read(key: 'dc_token');
  }

  Future<void> setBase(String value) async {
    base = value.trim().replaceAll(RegExp(r'/+$'), '');
    await _storage.write(key: 'dc_base', value: base);
  }

  Future<void> _saveToken(String value, {required bool remember}) async {
    token = value;
    if (remember) {
      await _storage.write(key: 'dc_token', value: value);
    } else {
      await _storage.delete(key: 'dc_token');
    }
  }

  Future<void> clearToken() async {
    token = null;
    await _storage.delete(key: 'dc_token');
  }

  Uri _uri(String path) => Uri.parse('$base/api/v1$path');

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<http.Response> _raw(String method, String path, [Json? body]) async {
    final req = http.Request(method, _uri(path))..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      return await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('Серверге қосылу мүмкін болмады ($base). Сервер іске қосылғанын және мекенжайды тексеріңіз.');
    }
  }

  Future<Json> _send(String method, String path, [Json? body]) async {
    final res = await _raw(method, path, body);
    if (res.statusCode == 204) return {};
    Json data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes)) as Json;
    } catch (_) {
      data = {};
    }
    if (res.statusCode >= 400) {
      final errors = <String, String>{};
      final raw = data['errors'];
      if (raw is Map) raw.forEach((k, v) => errors['$k'] = '$v');
      throw ApiException(data['error'] as String? ?? 'Сервер қатесі (${res.statusCode})',
          status: res.statusCode, errors: errors);
    }
    return data;
  }

  // ---- Кіру / тіркелу ----
  Future<Json> login(String login, String password, {required bool remember}) async {
    final d = await _send('POST', '/auth/login', {'login': login, 'password': password});
    await _saveToken(d['token'] as String, remember: remember);
    return d['user'] as Json;
  }

  Future<Json> register(Json form) async {
    final d = await _send('POST', '/auth/register', form);
    await _saveToken(d['token'] as String, remember: true);
    return d['user'] as Json;
  }

  Future<String> forgot(String email) async =>
      (await _send('POST', '/auth/forgot', {'email': email}))['message'] as String? ?? '';

  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout');
    } on ApiException {
      // токен онсыз да жарамсыз болуы мүмкін — бәрібір шығамыз
    }
    await clearToken();
  }

  // ---- Деректер ----
  Future<Json> meta() => _send('GET', '/meta');
  Future<Json> me() async => (await _send('GET', '/me'))['user'] as Json;
  Future<Json> dashboard() => _send('GET', '/dashboard');
  Future<Json> addParcel(Json form) async => (await _send('POST', '/parcels', form))['parcel'] as Json;
  Future<void> deleteParcel(int id) => _send('DELETE', '/parcels/$id');

  Future<String> reportCsv() async {
    final res = await _raw('GET', '/report.csv');
    if (res.statusCode != 200) throw ApiException('Есепті алу мүмкін болмады (${res.statusCode})', status: res.statusCode);
    return utf8.decode(res.bodyBytes).replaceFirst('﻿', '');
  }

  /// Қазақстан шекарасы (сайттағы static/data/kazakhstan.geojson).
  Future<Json> kazakhstanBorder() async {
    final res = await http.get(Uri.parse('$base/static/data/kazakhstan.geojson')).timeout(const Duration(seconds: 15));
    return jsonDecode(utf8.decode(res.bodyBytes)) as Json;
  }
}
