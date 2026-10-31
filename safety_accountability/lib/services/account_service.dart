import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class AccountException implements Exception {
  final String message;
  AccountException(this.message);
  @override
  String toString() => message;
}

class AccountService {
  // Same key AuthService uses for the cached user.
  static const _userKey = 'auth_user';

  static Uri _u(String path) => Uri.parse('${AuthService.baseUrl}$path');

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw AccountException(_extractError(res));
  }

  static String _extractError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        if (body['detail'] != null) return body['detail'].toString();
        if (body.keys.isNotEmpty) {
          final v = body[body.keys.first];
          if (v is List && v.isNotEmpty) return v.first.toString();
          return v.toString();
        }
      }
    } catch (_) {}
    return 'Something went wrong (${res.statusCode}).';
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final res = await http.post(
      _u('/api/accounts/change-password/'),
      headers: await _headers(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_new_password': confirmNewPassword,
      }),
    );
    _checkStatus(res);
  }

  // ---------------------------------------------------------- phone number

  /// Adds the phone number to an account that was created with Google
  /// (Google doesn't give us one). Returns the updated user.
  static Future<Map<String, dynamic>> setPhone(String phoneNumber) async {
    try {
      final res = await http
          .post(
            _u('/api/accounts/phone/'),
            headers: await _headers(),
            body: jsonEncode({'phone_number': phoneNumber}),
          )
          .timeout(const Duration(seconds: 20));
      return await _readUserAndCache(res);
    } on AccountException {
      rethrow;
    } catch (_) {
      throw AccountException('Could not reach the server. Please try again.');
    }
  }

  // ---------------------------------------------------------- profile photo

  static Future<Map<String, dynamic>> _readUserAndCache(http.Response res) async {
    _checkStatus(res);
    final user = jsonDecode(res.body) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
    return user;
  }

  /// Rejects a picture that has no human face in it (a cat, a logo, a
  /// landscape). Only runs on Android and iOS. If the detector itself cannot
  /// run, the picture is let through rather than blocking the person.
  static Future<void> _requireHumanFace(File photo) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    bool? foundFace;
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );
    try {
      final faces = await detector.processImage(InputImage.fromFilePath(photo.path));
      foundFace = faces.isNotEmpty;
    } catch (_) {
      foundFace = null; // detector unavailable: do not block the upload
    } finally {
      try {
        await detector.close();
      } catch (_) {}
    }

    if (foundFace == false) {
      throw AccountException(
        'We could not see a face in that picture. Please choose a clear photo of yourself.',
      );
    }
  }

  /// Uploads [photo] as the profile picture. Returns the updated user.
  static Future<Map<String, dynamic>> uploadProfilePhoto(File photo) async {
    final token = await AuthService.getToken();
    if (token == null) throw AccountException('You need to be signed in to do this.');
    try {
      await _requireHumanFace(photo);
      final request = http.MultipartRequest('POST', _u('/api/accounts/profile-photo/'))
        ..headers['Authorization'] = 'Token $token'
        ..files.add(await http.MultipartFile.fromPath('photo', photo.path));
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      return await _readUserAndCache(res);
    } on AccountException {
      rethrow;
    } catch (_) {
      throw AccountException('Could not upload the picture. Check your connection and try again.');
    }
  }

  /// Removes the profile picture. Returns the updated user.
  static Future<Map<String, dynamic>> removeProfilePhoto() async {
    try {
      final res = await http
          .delete(_u('/api/accounts/profile-photo/'), headers: await _headers())
          .timeout(const Duration(seconds: 20));
      return await _readUserAndCache(res);
    } on AccountException {
      rethrow;
    } catch (_) {
      throw AccountException('Could not reach the server.');
    }
  }
}