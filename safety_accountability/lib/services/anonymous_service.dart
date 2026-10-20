import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class AnonymousException implements Exception {
  final String message;
  AnonymousException(this.message);
  @override
  String toString() => message;
}

/// Anonymous reporting. No login and no token is ever sent. The only link
/// between a person and their report is the tracking code, which is kept
/// on this device only.
class AnonymousService {
  static const _codesKey = 'anon_tracking_codes';

  // ---------------- Saved tracking codes (device only) ----------------

  static Future<List<String>> getSavedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_codesKey) ?? [];
  }

  static Future<void> saveCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final codes = prefs.getStringList(_codesKey) ?? [];
    if (!codes.contains(code)) {
      codes.insert(0, code);
      await prefs.setStringList(_codesKey, codes);
    }
  }

  static Future<void> removeCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final codes = prefs.getStringList(_codesKey) ?? [];
    codes.remove(code);
    await prefs.setStringList(_codesKey, codes);
  }

  // ---------------- API ----------------

  /// Returns the tracking code of the new report.
  static Future<String> submitReport({
    required String category, // slug, e.g. 'drug_activity'
    required String location,
    required String description,
    required String urgency,
    required bool involvesMinors,
    required bool requiresImmediateAction,
    required List<PlatformFile> files,
  }) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/reports/submit/');
    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['category'] = category
        ..fields['location'] = location
        ..fields['description'] = description
        ..fields['urgency'] = urgency
        ..fields['involves_minors'] = involvesMinors.toString()
        ..fields['requires_immediate_action'] = requiresImmediateAction.toString();

      for (final f in files) {
        final path = f.path;
        if (path != null) {
          request.files.add(await http.MultipartFile.fromPath('evidence', path, filename: f.name));
        }
      }

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);
      final body = _decode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final code = body['tracking_code']?.toString();
        if (code == null || code.isEmpty) {
          throw AnonymousException('The server did not return a tracking code.');
        }
        await saveCode(code);
        return code;
      }
      throw AnonymousException(_errorMessage(response.statusCode, body));
    } on AnonymousException {
      rethrow;
    } catch (_) {
      throw AnonymousException('Could not reach the server. Check your connection and try again.');
    }
  }

  /// Looks up one report by its tracking code. Throws if not found.
  static Future<Map<String, dynamic>> trackReport(String code) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/reports/track/${Uri.encodeComponent(code.trim())}/');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      final body = _decode(response.body);
      if (response.statusCode == 200) return body;
      if (response.statusCode == 404) {
        throw AnonymousException('No report found for that tracking code.');
      }
      throw AnonymousException(_errorMessage(response.statusCode, body));
    } on AnonymousException {
      rethrow;
    } catch (_) {
      throw AnonymousException('Could not reach the server.');
    }
  }

  // ---------------- internals ----------------

  static Map<String, dynamic> _decode(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  static String _errorMessage(int status, Map<String, dynamic> body) {
    if (status == 429) return 'Too many requests. Please wait a moment and try again.';
    if (body['detail'] != null) return body['detail'].toString();
    final parts = <String>[];
    body.forEach((key, value) {
      parts.add(value is List ? value.join(' ') : value.toString());
    });
    return parts.isNotEmpty ? parts.join(' ') : 'Something went wrong. Please try again.';
  }
}