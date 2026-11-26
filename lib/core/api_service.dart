import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ApiService {
  ApiService._() {
    baseUrl = candidateBaseUrls.first;
  }
  static final ApiService instance = ApiService._();

  static const _tokenKey = 'master_dnd_auth_token';
  static const _userKey = 'master_dnd_cached_user';
  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Production Microsoft Azure App Service Cloud API URL (Live 24/7)
  static const String _azureUrl =
      'https://master-dnd-atulya-fje0aze7fkfjarfa.centralindia-01.azurewebsites.net/api';

  /// Local development Mac LAN IPs to support physical Android/iOS devices on the local Wi-Fi
  static const String _currentLanHost = '192.168.31.183:5001';
  static const String _fallbackLanHost = '192.168.31.29:5001';
  static const String _activeUrlPrefKey = 'master_dnd_active_base_url';

  static List<String> get candidateBaseUrls {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return [envUrl];

    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return [
        _azureUrl,
        'http://$host:5001/api',
        'http://localhost:5001/api',
        'http://127.0.0.1:5001/api',
      ];
    }
    try {
      if (Platform.isAndroid) {
        return [
          _azureUrl,                       // Live Azure Cloud Backend
          'http://$_currentLanHost/api',   // Physical Android phone over Wi-Fi
          'http://10.0.2.2:5001/api',       // Android Emulator host loopback
          'http://127.0.0.1:5001/api',      // adb reverse tcp:5001 tcp:5001
          'http://localhost:5001/api',
          'http://$_fallbackLanHost/api',
        ];
      }
      if (Platform.isIOS) {
        return [
          _azureUrl,                       // Live Azure Cloud Backend
          'http://$_currentLanHost/api',   // Physical iPhone over Wi-Fi
          'http://localhost:5001/api',      // iOS Simulator
          'http://127.0.0.1:5001/api',
          'http://$_fallbackLanHost/api',
        ];
      }
    } catch (_) {}
    return [
      _azureUrl,
      'http://localhost:5001/api',
      'http://127.0.0.1:5001/api',
      'http://$_currentLanHost/api',
      'http://$_fallbackLanHost/api',
    ];
  }

  static String get defaultBaseUrl => candidateBaseUrls.first;

  late String baseUrl;
  String? _verifiedBaseUrl;

  Future<void> setCustomBaseUrl(String url) async {
    _verifiedBaseUrl = url;
    baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUrlPrefKey, url);
  }

  Future<String> resolveBaseUrl() async {
    if (_verifiedBaseUrl != null) return _verifiedBaseUrl!;

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_activeUrlPrefKey);

    // 1. Check previously verified URL first for ultra-fast startup (<50ms)
    if (cached != null && cached.isNotEmpty) {
      try {
        final probeUri = Uri.parse(cached.replaceAll('/api', '/api/health'));
        final res = await http.get(probeUri).timeout(const Duration(milliseconds: 1000));
        if (res.statusCode == 200) {
          _verifiedBaseUrl = cached;
          baseUrl = cached;
          return cached;
        }
      } catch (_) {}
    }

    final candidates = candidateBaseUrls;
    if (candidates.length <= 1) {
      _verifiedBaseUrl = candidates.first;
      baseUrl = candidates.first;
      return _verifiedBaseUrl!;
    }

    // 2. Fast parallel probe across all candidate endpoints (<1200ms max)
    final probeFutures = candidates.map((candidate) async {
      try {
        final probeUri = Uri.parse(candidate.replaceAll('/api', '/api/health'));
        final res = await http.get(probeUri).timeout(const Duration(milliseconds: 1200));
        if (res.statusCode == 200) {
          return candidate;
        }
      } catch (_) {}
      return null;
    });

    final results = await Future.wait(probeFutures);
    for (final working in results) {
      if (working != null) {
        debugPrint('[ApiService] Verified active backend endpoint: $working');
        _verifiedBaseUrl = working;
        baseUrl = working;
        await prefs.setString(_activeUrlPrefKey, working);
        return working;
      }
    }

    // 3. Fallback to candidate default
    _verifiedBaseUrl = candidates.first;
    baseUrl = candidates.first;
    return _verifiedBaseUrl!;
  }

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
      return 'Request timed out after ${_requestTimeout.inSeconds}s. Please verify the backend is running at $baseUrl.';
    }
    if (e is SocketException) {
      return 'Cannot reach backend at $baseUrl. Ensure backend server is running on port 5001.';
    }
    final raw = e.toString().replaceAll('Exception: ', '');
    if (raw.contains('XMLHttpRequest') || raw.contains('ClientException')) {
      return 'Connection error: Unable to reach backend at $baseUrl. Ensure port 5001 is accessible.';
    }
    return raw;
  }

  Map<String, dynamic> _safeDecodeJson(String body, int statusCode) {
    if (body.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } catch (e) {
      debugPrint('[ApiService] JSON decode warning: $e for status $statusCode. Body snippet: ${body.length > 200 ? body.substring(0, 200) : body}');
      return {};
    }
  }

  // -------------------------------------------------------------
  // AUTHENTICATION
  // -------------------------------------------------------------

  /// Request OTP for an email address
  Future<Map<String, dynamic>> sendOtp(String email) async {
    final activeBase = await resolveBaseUrl();
    final uri = Uri.parse('$activeBase/auth/send-otp');
    try {
      debugPrint('[ApiService.sendOtp] POST $uri for $email');
      final res = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({'email': email, 'identifier': email, 'phone': email}),
          )
          .timeout(_requestTimeout);

      debugPrint('[ApiService.sendOtp] Status: ${res.statusCode}');
      final data = _safeDecodeJson(res.body, res.statusCode);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return data;
      }
      final msg = data['message']?.toString() ??
          data['error']?.toString() ??
          'Failed to send OTP (Status: ${res.statusCode})';
      throw Exception(msg);
    } catch (e, stack) {
      _verifiedBaseUrl = null; // Re-probe on connection failure
      debugPrint('[ApiService.sendOtp] Error: $e\n$stack');
      throw Exception(_formatNetworkError(e));
    }
  }

  /// Verify OTP code and retrieve JWT session token
  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final activeBase = await resolveBaseUrl();
    final uri = Uri.parse('$activeBase/auth/verify-otp');
    try {
      debugPrint('[ApiService.verifyOtp] POST $uri for $email');
      final res = await http
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({'email': email, 'identifier': email, 'phone': email, 'otp': otp}),
          )
          .timeout(_requestTimeout);

      debugPrint('[ApiService.verifyOtp] Status: ${res.statusCode}');
      final data = _safeDecodeJson(res.body, res.statusCode);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final token = data['token']?.toString();
        if (token != null) {
          await setToken(token);
        }
        return data;
      }
      final msg = data['message']?.toString() ??
          data['error']?.toString() ??
          'Failed to verify OTP code (Status: ${res.statusCode})';
      throw Exception(msg);
    } catch (e, stack) {
      _verifiedBaseUrl = null;
      debugPrint('[ApiService.verifyOtp] Error: $e\n$stack');
      throw Exception(_formatNetworkError(e));
    }
  }

  // -------------------------------------------------------------
  // USER PROFILE
  // -------------------------------------------------------------

  Future<UserModel> getProfile() async {
    final token = await getToken();
    if (token == null) throw Exception('No session token');

    final activeBase = await resolveBaseUrl();
    final uri = Uri.parse('$activeBase/user/profile');
    try {
      final res = await http
          .get(uri, headers: _headers(token))
          .timeout(_requestTimeout);

      final data = _safeDecodeJson(res.body, res.statusCode);
      if (res.statusCode == 200 && data['user'] != null) {
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      throw Exception(data['message'] ?? 'Failed to fetch user profile (Status: ${res.statusCode})');
    } catch (e, stack) {
      _verifiedBaseUrl = null;
      debugPrint('[ApiService.getProfile] Error: $e\n$stack');
      throw Exception(_formatNetworkError(e));
    }
  }

  Future<UserModel> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? bio,
    Map<String, bool>? notificationPreferences,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('No session token');

    final activeBase = await resolveBaseUrl();
    final uri = Uri.parse('$activeBase/user/profile');
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (avatar != null) body['avatar'] = avatar;
    if (bio != null) body['bio'] = bio;
    if (notificationPreferences != null) {
      body['notificationPreferences'] = notificationPreferences;
    }

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
      _verifiedBaseUrl = null;
      throw Exception(_formatNetworkError(e));
    }
  }

  Future<UserModel> updatePreferences({
    int? addDurationMinutes,
    int? removeDurationMinutes,
    String? addContactCategory,
    String? addWhitelistOption,
    Map<String, bool>? notificationPreferences,
    int? activeSessionPlannedMinutes,
    DateTime? activeSessionEndTime,
    String? activeProfileName,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('No session token');

    final activeBase = await resolveBaseUrl();
    final uri = Uri.parse('$activeBase/user/preferences');
    final Map<String, dynamic> body = {};
    if (addDurationMinutes != null) body['addDurationMinutes'] = addDurationMinutes;
    if (removeDurationMinutes != null) body['removeDurationMinutes'] = removeDurationMinutes;
    if (addContactCategory != null) body['addContactCategory'] = addContactCategory;
    if (addWhitelistOption != null) body['addWhitelistOption'] = addWhitelistOption;
    if (notificationPreferences != null) {
      body['notificationPreferences'] = notificationPreferences;
    }
    if (activeSessionPlannedMinutes != null) {
      body['activeSessionPlannedMinutes'] = activeSessionPlannedMinutes;
    }
    if (activeSessionEndTime != null) {
      body['activeSessionEndTime'] = activeSessionEndTime.toIso8601String();
    }
    if (activeProfileName != null) {
      body['activeProfileName'] = activeProfileName;
    }

    try {
      final res = await http
          .put(
            uri,
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      final data = _safeDecodeJson(res.body, res.statusCode);
      if (res.statusCode == 200 && data['user'] != null) {
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      throw Exception(data['message'] ?? 'Failed to save preferences');
    } catch (e) {
      throw Exception(_formatNetworkError(e));
    }
  }

  Future<List<LetThroughContact>> getContacts() async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/user/contacts');
      final res = await http.get(uri, headers: _headers(token)).timeout(_requestTimeout);
      if (res.statusCode == 200) {
        final data = _safeDecodeJson(res.body, res.statusCode);
        final list = data['contacts'] as List<dynamic>? ?? [];
        return list.map((e) => LetThroughContact.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService.getContacts] Error: $e');
    }
    return [];
  }

  Future<List<LetThroughContact>> addContact({
    required String name,
    String phone = '',
    String relationship = 'VIP Contact',
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('No session token');

    final activeBase = await resolveBaseUrl();
    final uri = Uri.parse('$activeBase/user/contacts');
    final res = await http
        .post(
          uri,
          headers: _headers(token),
          body: jsonEncode({
            'name': name,
            'phone': phone,
            'relationship': relationship,
            'isVip': true,
          }),
        )
        .timeout(_requestTimeout);

    final data = _safeDecodeJson(res.body, res.statusCode);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = data['contacts'] as List<dynamic>? ?? [];
      return list.map((e) => LetThroughContact.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception(data['message'] ?? 'Failed to add contact');
  }

  Future<List<LetThroughContact>> deleteContact(String contactId) async {
    final token = await getToken();
    if (token == null) throw Exception('No session token');

    final activeBase = await resolveBaseUrl();
    final uri = Uri.parse('$activeBase/user/contacts/$contactId');
    final res = await http.delete(uri, headers: _headers(token)).timeout(_requestTimeout);
    final data = _safeDecodeJson(res.body, res.statusCode);
    if (res.statusCode == 200) {
      final list = data['contacts'] as List<dynamic>? ?? [];
      return list.map((e) => LetThroughContact.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception(data['message'] ?? 'Failed to remove contact');
  }

  // -------------------------------------------------------------
  // DND PROFILES & CONTROL
  // -------------------------------------------------------------

  Future<List<DndProfile>> getProfiles() async {
    final token = await getToken();
    if (token == null) return sampleProfiles;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/profiles');
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

  Future<DndProfile?> createDndProfile(DndProfile profile) async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/profiles');
      final res = await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode(profile.toJson()),
          )
          .timeout(_requestTimeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['profile'] != null) {
          return DndProfile.fromJson(data['profile'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[ApiService.createDndProfile] Error: $e');
    }
    return null;
  }

  Future<void> updateDndProfile(DndProfile profile) async {
    final token = await getToken();
    if (token == null) return;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/profiles/${profile.id}');
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

  Future<bool> deleteDndProfile(String profileId) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/profiles/$profileId');
      final res = await http
          .delete(uri, headers: _headers(token))
          .timeout(_requestTimeout);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService.deleteDndProfile] Error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> toggleMasterDnd({
    bool? enabled,
    int? durationMinutes,
    DateTime? endTime,
    String? profileName,
  }) async {
    final token = await getToken();
    if (token == null) return {'dndEnabled': enabled ?? false};

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/toggle');
      final Map<String, dynamic> body = {};
      if (enabled != null) body['enabled'] = enabled;
      if (durationMinutes != null) body['durationMinutes'] = durationMinutes;
      if (endTime != null) body['endTime'] = endTime.toIso8601String();
      if (profileName != null && profileName.isNotEmpty) body['profileName'] = profileName;

      final res = await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      if (res.statusCode == 200) {
        return _safeDecodeJson(res.body, res.statusCode);
      }
    } catch (e) {
      debugPrint('[ApiService.toggleMasterDnd] Error: $e');
    }
    return {'dndEnabled': enabled ?? false};
  }

  // -------------------------------------------------------------
  // RULES & SCHEDULES
  // -------------------------------------------------------------

  Future<List<DndRule>> getRules() async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/rules');
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

  Future<DndRule?> createRule(DndRule rule) async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/rules');
      final res = await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode(rule.toJson()),
          )
          .timeout(_requestTimeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['rule'] != null) {
          return DndRule.fromJson(data['rule'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[ApiService.createRule] Error: $e');
    }
    return null;
  }

  Future<bool> updateRule(
    String ruleId, {
    bool? active,
    String? title,
    String? subtitle,
    String? triggerType,
    List<String>? days,
    String? targetProfileName,
    String? customCondition,
  }) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/rules/$ruleId');
      final Map<String, dynamic> body = {};
      if (active != null) body['active'] = active;
      if (title != null) body['title'] = title;
      if (subtitle != null) body['subtitle'] = subtitle;
      if (triggerType != null) body['triggerType'] = triggerType;
      if (days != null) body['days'] = days;
      if (targetProfileName != null) body['targetProfileName'] = targetProfileName;
      if (customCondition != null) body['customCondition'] = customCondition;

      final res = await http
          .put(
            uri,
            headers: _headers(token),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService.updateRule] Error: $e');
      return false;
    }
  }

  Future<bool> deleteRule(String ruleId) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/rules/$ruleId');
      final res = await http
          .delete(uri, headers: _headers(token))
          .timeout(_requestTimeout);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService.deleteRule] Error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------
  // ACTIVITY LOGS, APP USAGE & STABILITY ANALYTICS
  // -------------------------------------------------------------

  Future<List<DndActivityLog>> getActivityLogs() async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/logs');
      final res = await http.get(uri, headers: _headers(token)).timeout(_requestTimeout);
      if (res.statusCode == 200) {
        final data = _safeDecodeJson(res.body, res.statusCode);
        final list = data['logs'] as List<dynamic>? ?? [];
        return list.map((e) => DndActivityLog.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ApiService.getActivityLogs] Error: $e');
    }
    return [];
  }

  Future<DndActivityLog?> createActivityLog({
    required String profileName,
    required int durationMinutes,
    int? plannedMinutes,
    bool completedWithoutEarlyExit = true,
    int silencedCount = 0,
    int letThroughCount = 0,
    int focusStabilityRating = 4,
    String notes = '',
    DateTime? date,
  }) async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/logs');
      final res = await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode({
              'profileName': profileName,
              'durationMinutes': durationMinutes,
              'plannedMinutes': plannedMinutes ?? durationMinutes,
              'completedWithoutEarlyExit': completedWithoutEarlyExit,
              'silencedCount': silencedCount,
              'letThroughCount': letThroughCount,
              'focusStabilityRating': focusStabilityRating,
              'notes': notes,
              if (date != null) 'date': date.toIso8601String(),
            }),
          )
          .timeout(_requestTimeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = _safeDecodeJson(res.body, res.statusCode);
        if (data['log'] != null) {
          return DndActivityLog.fromJson(data['log'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[ApiService.createActivityLog] Error: $e');
    }
    return null;
  }

  Future<bool> deleteActivityLog(String logId) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/logs/$logId');
      final res = await http.delete(uri, headers: _headers(token)).timeout(_requestTimeout);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService.deleteActivityLog] Error: $e');
      return false;
    }
  }

  Future<int?> pingAppUsage({int minutes = 1}) async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/usage-ping');
      final res = await http
          .post(
            uri,
            headers: _headers(token),
            body: jsonEncode({'minutes': minutes}),
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = _safeDecodeJson(res.body, res.statusCode);
        return (data['totalAppUsageMinutes'] as num?)?.toInt();
      }
    } catch (e) {
      debugPrint('[ApiService.pingAppUsage] Error: $e');
    }
    return null;
  }

  Future<InsightsData> getInsights({int range = 0}) async {
    final token = await getToken();
    if (token == null) return InsightsData.empty();

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/insights?range=$range');
      final res = await http
          .get(uri, headers: _headers(token))
          .timeout(_requestTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return InsightsData.fromJson(data);
      }
    } catch (e) {
      debugPrint('[ApiService.getInsights] Error: $e');
    }
    return InsightsData.empty();
  }

  Future<StabilityReportData> getStabilityReport({int range = 0}) async {
    final token = await getToken();
    if (token == null) return StabilityReportData.empty();

    try {
      final activeBase = await resolveBaseUrl();
      final uri = Uri.parse('$activeBase/dnd/stability-report?range=$range');
      final res = await http.get(uri, headers: _headers(token)).timeout(_requestTimeout);

      if (res.statusCode == 200) {
        final data = _safeDecodeJson(res.body, res.statusCode);
        return StabilityReportData.fromJson(data);
      }
    } catch (e) {
      debugPrint('[ApiService.getStabilityReport] Error: $e');
    }
    return StabilityReportData.empty();
  }

  // -------------------------------------------------------------
  // SYSTEM HEALTH & DIAGNOSTICS
  // -------------------------------------------------------------

  Future<Map<String, dynamic>> checkSystemHealth() async {
    final activeBase = await resolveBaseUrl();
    final healthUri = Uri.parse(activeBase.replaceAll('/api', '/api/health'));
    final stopwatch = Stopwatch()..start();
    try {
      final res = await http.get(healthUri).timeout(const Duration(seconds: 4));
      stopwatch.stop();
      if (res.statusCode == 200) {
        final data = _safeDecodeJson(res.body, res.statusCode);
        return {
          'online': true,
          'latencyMs': stopwatch.elapsedMilliseconds,
          'status': data['status'] ?? 'healthy',
          'service': data['service'] ?? 'Master DND API',
          'version': data['version'] ?? '1.1.0',
          'environment': data['environment'] ?? 'production',
          'dbConnected': data['dbConnected'] == true,
          'storageMode': data['storageMode'] ?? 'in_memory_fallback',
          'smtpConfigured': data['smtpConfigured'] == true,
          'uptimeSeconds': data['uptimeSeconds'] ?? 0,
          'baseUrl': activeBase,
        };
      }
      return {
        'online': false,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'status': 'http_${res.statusCode}',
        'baseUrl': activeBase,
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'online': false,
        'latencyMs': stopwatch.elapsedMilliseconds,
        'error': e.toString(),
        'baseUrl': activeBase,
      };
    }
  }
}
