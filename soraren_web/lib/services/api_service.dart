// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'hash_service.dart';
import '../utils/safe_log.dart';
import '../utils/safe_error.dart';

class ApiService {
  // New Backend Base URL
  static const String baseUrl = 'https://auth-backend-6dqr.onrender.com';

  final HashService _hasher = HashService();

  // Security: Forces Android to use AES-GCM (EncryptedSharedPreferences)
  AndroidOptions _getAndroidOptions() => const AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  late final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: _getAndroidOptions(),
  );

  // Storage Keys - Consistent with SessionGuard
  static const String _kJwt = 'jwt';
  static const String _kLoginTime = 'login_timestamp';
  static const String _kLastActive = 'last_active_timestamp';

  // ---------------------------------------------------------
  // SESSION & TOKEN HELPERS
  // ---------------------------------------------------------

  Future<String?> getToken() => _secureStorage.read(key: _kJwt);

  /// Clears local session data for logout
  Future<void> localLogout() => deleteToken();


  Future<Map<String, dynamic>> logoutServer(String userId) async {
    final uri = Uri.parse('$baseUrl/api/auth/logout/$userId'); // Adjust path if backend differs
    final token = await getToken();
    try {
      final resp = await http.post(uri, headers: _headers(token: token)).timeout(const Duration(seconds: 10));
      await deleteToken();
      return {'ok': true, 'data': _safeJson(resp.body)};
    } catch (e) {
      await deleteToken();
      return {'ok': false, 'message': SafeError.format(e)};
    }
  }



  Future<void> saveToken(String token) async {
    final now = DateTime.now().toIso8601String();
    await _secureStorage.write(key: _kJwt, value: token);
    await _secureStorage.write(key: _kLoginTime, value: now);
    await _secureStorage.write(key: _kLastActive, value: now);
  }

  Future<void> updateLastActivity() async {
    final now = DateTime.now().toIso8601String();
    await _secureStorage.write(key: _kLastActive, value: now);
  }

  /// Retrieves the timestamp of the last recorded user interaction
  Future<DateTime?> getLastActiveTimestamp() async {
    final str = await _secureStorage.read(key: _kLastActive);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// Retrieves the timestamp when the current session began
  Future<DateTime?> getLoginTimestamp() async {
    final str = await _secureStorage.read(key: _kLoginTime);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: _kJwt);
    await _secureStorage.delete(key: _kLoginTime);
    await _secureStorage.delete(key: _kLastActive);
  }

  Map<String, String> _headers({String? token, bool isMultipart = false}) {
    final Map<String, String> headerMap = {
      'accept': 'application/json',
    };
    if (!isMultipart) headerMap['Content-Type'] = 'application/json';
    if (token != null) headerMap['Authorization'] = 'Bearer $token';
    return headerMap;
  }

  // ---------------------------------------------------------
  // 1. AUTHENTICATION (New Backend)
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> login(String userId, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    final String hashedPassword = _hasher.hashPassword(password);

    try {
      //final payload = {'user_id': userId, 'password': hashedPassword};

      // Hashing disabled for now... change the line below to the one above
      final payload = {'user_id': userId, 'password': password};

      final resp = await http.post(uri, headers: _headers(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 20));

      final body = _safeJson(resp.body);
      // Map 'token' to 'jwt' for saveToken consistency
      if (resp.statusCode == 200 && body['token'] != null) {
        await saveToken(body['token']);
        return {'ok': true, 'data': body};
      }
      return {'ok': false, 'message': body['message'] ?? 'Login failed'};
    } catch (e) {
      return {'ok': false, 'message': SafeError.format(e)};
    }
  }

  // ---------------------------------------------------------
  // 2. USER MANAGEMENT (Admin)
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> addUser({
    required String userId,
    required String name,
    required String contact,
    required String role,
    required String password,
    String status = 'active',
  }) async {
    final uri = Uri.parse('$baseUrl/api/users');
    final token = await getToken();
    final payload = {
      'user_id': userId,
      'name': name,
      'contact_number': contact,
      'status': status,
      'role': role,
      'password': _hasher.hashPassword(password),
    };

    return _authenticatedRequest(() => http.post(uri, headers: _headers(token: token), body: jsonEncode(payload)));
  }

  Future<Map<String, dynamic>> editUser(String userId, Map<String, dynamic> updates) async {
    final uri = Uri.parse('$baseUrl/api/users/$userId');
    final token = await getToken();
    return _authenticatedRequest(() => http.put(uri, headers: _headers(token: token), body: jsonEncode(updates)));
  }

  Future<Map<String, dynamic>> deleteUser(String userId) async {
    final uri = Uri.parse('$baseUrl/api/users/$userId');
    final token = await getToken();
    return _authenticatedRequest(() => http.delete(uri, headers: _headers(token: token)));
  }

  // ---------------------------------------------------------
  // 3. SUSPECT MANAGEMENT
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> listSuspects() async {
    final uri = Uri.parse('$baseUrl/api/suspects');
    final token = await getToken();
    return _authenticatedRequest(() => http.get(uri, headers: _headers(token: token)));
  }

  Future<Map<String, dynamic>> addSuspect(String personName, File imageFile) async {
    final uri = Uri.parse('$baseUrl/api/suspects/add');
    final token = await getToken();

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers(token: token, isMultipart: true));
      request.fields['person_name'] = personName;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResp = await request.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamedResp);
      return _handleResponse(resp);
    } catch (e) {
      return {'ok': false, 'message': SafeError.format(e)};
    }
  }

  Future<Map<String, dynamic>> deleteSuspect(String personName) async {
    final uri = Uri.parse('$baseUrl/api/suspects/delete');
    final token = await getToken();
    final payload = {'person_name': personName};

    return _authenticatedRequest(() => http.post(uri, headers: _headers(token: token), body: jsonEncode(payload)));
  }

  Future<Map<String, dynamic>> recognizeSuspect(File imageFile) async {
    final uri = Uri.parse('$baseUrl/api/suspects/recognize');
    final token = await getToken();

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headers(token: token, isMultipart: true));
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final streamedResp = await request.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamedResp);
      return _handleResponse(resp);
    } catch (e) {
      return {'ok': false, 'message': SafeError.format(e)};
    }
  }

  // ---------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------

  Future<Map<String, dynamic>> _authenticatedRequest(Future<http.Response> Function() requestFn) async {
    try {
      final resp = await requestFn().timeout(const Duration(seconds: 15));
      return _handleResponse(resp);
    } catch (e) {
      return {'ok': false, 'message': SafeError.format(e)};
    }
  }

  Map<String, dynamic> _handleResponse(http.Response resp) {
    final body = _safeJson(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return {'ok': true, 'data': body};
    } else if (resp.statusCode == 401 || resp.statusCode == 403) {
      return {'ok': false, 'message': 'Session expired', 'code': resp.statusCode};
    }
    return {'ok': false, 'message': body['message'] ?? 'Error ${resp.statusCode}', 'data': body};
  }

  dynamic _safeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'raw': body};
    }
  }
}