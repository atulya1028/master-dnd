import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ApiService {
  ApiService._() {
    baseUrl = defaultBaseUrl;
  }
  static final ApiService instance = ApiService._();

  static const _tokenKey = 'master_dnd_auth_token';
  static const _userKey = 'master_dnd_cached_user';
  static const Duration _requestTimeout = Duration(seconds: 25);

  /// Determines appropriate local host for Android emulator vs iOS/macOS/web,
  /// or loads a production URL passed via --dart-define=API_URL=https://...
  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return 'http://$host:5001/api';
    }
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5001/api';
    } catch (_) {}
    return 'http://localhost:5001/api';
  }

  late String baseUrl;

  String? _cachedToken;

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> setToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearSession() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  String _formatNetworkError(dynamic e) {
    if (e is TimeoutException) {
      return 'Server response timed out. Make sure the backend server is running at $baseUrl.';
    }
    if (e is SocketException) {
      return 'Cannot reach backend at $baseUrl. Ensure "npm run dev" is running.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  // -------------------------------------------------------------
  // AUTHENTICATION
  // -------------------------------------------------------------

  /// Request OTP for a phone number
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final uri = Uri.parse('$baseUrl/auth/send-otp');
    try {
      final res = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({'email': phone, 'identifier': phone, 'phone': phone}),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to send OTP (Status: ${res.statusCode})');
    } catch (e) {
      debugPrint('[ApiService.sendOtp] Error: $e');
      throw Exception(_formatNetworkError(e));
    }
  }

  /// Verify OTP code and retrieve JWT session token
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final uri = Uri.parse('$baseUrl/auth/verify-otp');
    try {
      final res = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({'email': phone, 'identifier': phone, 'phone': phone, 'otp': otp}),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final token = data['token']?.toString();
        if (token != null) {
          await setToken(token);
        }
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to verify OTP code');
    } catch (e) {
      debugPrint('[ApiService.verifyOtp] Error: $e');
      throw Exception(_formatNetworkError(e));
    }
  }

  // -------------------------------------------------------------
  // USER PROFILE
  // -------------------------------------------------------------

  Future<UserModel> getProfile() async {
    final token = await getToken();
    if (token == null) throw Exception('No session token');

    final uri = Uri.parse('$baseUrl/user/profile');
    try {
      final res = await http
          .get(uri, headers: _headers(token))
          .timeout(_requestTimeout);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['user'] != null) {
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      throw Exception(data['message'] ?? 'Failed to fetch user profile');
    } catch (e) {
      throw Exception(_formatNetworkError(e));
    }
  }

  Future<UserModel> updateProfile({
    String? name,
    String? email,
    String? avatar,
    String? bio,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('No session token');

    final uri = Uri.parse('$baseUrl/user/profile');
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (avatar != null) body['avatar'] = avatar;
    if (bio != null) body['bio'] = bio;

    try {
      final res = await http
          .put(
            uri,
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && data['user'] != null) {
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      throw Exception(data['message'] ?? 'Failed to update profile');
    } catch (e) {
      throw Exception(_formatNetworkError(e));
    }
  }

  // -------------------------------------------------------------
  // DND PROFILES & CONTROL
  // -------------------------------------------------------------

  Future<List<DndProfile>> getProfiles() async {
    final token = await getToken();
    if (token == null) return sampleProfiles;

    try {
      final uri = Uri.parse('$baseUrl/dnd/profiles');
      final res = await http
          .get(uri, headers: _headers(token))
          .timeout(_requestTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['profiles'] as List<dynamic>? ?? [];
        return list.map((e) => DndProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService.getProfiles] Error: $e');
    }
    return sampleProfiles;
  }

  Future<void> updateDndProfile(DndProfile profile) async {
    final token = await getToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('$baseUrl/dnd/profiles/${profile.id}');
      await http
          .put(
            uri,
            headers: _headers(token),
            body: jsonEncode(profile.toJson()),
          )
          .timeout(_requestTimeout);
    } catch (e) {
      debugPrint('[ApiService.updateDndProfile] Error: $e');
    }
  }

  Future<bool> toggleMasterDnd({bool? enabled}) async {
    final token = await getToken();
    if (token == null) return enabled ?? false;

    try {
      final uri = Uri.parse('$baseUrl/dnd/toggle');
      final Map<String, dynamic> body = {};
      if (enabled != null) body['enabled'] = enabled;

      final res = await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['dndEnabled'] == true;
      }
    } catch (e) {
      debugPrint('[ApiService.toggleMasterDnd] Error: $e');
    }
    return enabled ?? false;
  }

  Future<List<DndRule>> getRules() async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final uri = Uri.parse('$baseUrl/dnd/rules');
      final res = await http
          .get(uri, headers: _headers(token))
          .timeout(_requestTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['rules'] as List<dynamic>? ?? [];
        return list.map((e) => DndRule.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService.getRules] Error: $e');
    }
    return [];
  }
}
