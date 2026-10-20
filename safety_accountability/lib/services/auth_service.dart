import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Talks to the Django backend's /api/accounts/ endpoints and keeps the
/// logged-in user's token on-device between app launches.
///
/// IMPORTANT — baseUrl:
/// - Android emulator -> 'http://10.0.2.2:8000' (10.0.2.2 is the emulator's
///   special alias for your computer's own localhost) — this is the default
///   below.
/// - iOS simulator -> 'http://127.0.0.1:8000' works directly.
/// - A real phone on the same Wi-Fi as your computer -> use your computer's
///   LAN IP instead, e.g. 'http://192.168.1.42:8000' (find it on Windows
///   with `ipconfig`, look for "IPv4 Address" under your Wi-Fi adapter).
/// Change this one constant when you switch between testing setups.
class AuthService {
    static const String baseUrl = 'https://safetyaccountability.eu.pythonanywhere.com';

  /// The "Web application" OAuth client id from Google Cloud Console. Google
  /// uses it to issue an ID token that our Django backend can verify. This is
  /// an identifier, not a secret (never put the client SECRET in the app).
  static const String googleWebClientId =
      '988927463419-uhluijb932tngain0ca6clffqaio6p3d.apps.googleusercontent.com';

  static bool _googleReady = false;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  /// Signs up a new account. Throws an AuthException with a message ready
  /// to show the user if the backend rejects it (duplicate email, weak
  /// password, passwords not matching, etc).
  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/accounts/signup/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'password': password,
        'confirm_password': confirmPassword,
      }),
    );
    return _handleAuthResponse(response);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/accounts/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleAuthResponse(response);
  }

  /// Signs up or logs in with Google. Returns null if the person closed the
  /// Google window without choosing an account. Throws an AuthException with a
  /// readable message for real failures.
  static Future<({bool needsPhone, bool isNew})?> loginWithGoogle() async {
    final String idToken;
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(serverClientId: googleWebClientId);
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw AuthException('Google did not return a sign-in token. Please try again.');
      }
      idToken = token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthException('Google sign-in failed. ${e.description ?? 'Please try again.'}');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/accounts/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AuthException('Something went wrong (${response.statusCode}). Please try again.');
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      await _saveSession(body['token'] as String, body['user'] as Map<String, dynamic>);
      return (needsPhone: body['needs_phone'] == true, isNew: body['is_new'] == true);
    }
    throw AuthException(_extractErrorMessage(body));
  }

  static Future<Map<String, dynamic>> _handleAuthResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = body['token'] as String;
      final user = body['user'] as Map<String, dynamic>;
      await _saveSession(token, user);
      return user;
    }

    throw AuthException(_extractErrorMessage(body));
  }

  /// DRF validation errors arrive as {"field": ["message"]} or
  /// {"detail": "message"} — this flattens either shape into one readable
  /// string for a SnackBar.
  static String _extractErrorMessage(Map<String, dynamic> body) {
    if (body.containsKey('detail')) return body['detail'].toString();
    final messages = <String>[];
    body.forEach((field, value) {
      if (value is List) {
        messages.addAll(value.map((e) => e.toString()));
      } else {
        messages.add(value.toString());
      }
    });
    return messages.isNotEmpty ? messages.join('\n') : 'Something went wrong. Please try again.';
  }

  static Future<void> _saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Saves a refreshed copy of the user (e.g. after adding a phone number)
  /// without touching the login token.
  static Future<void> updateCachedUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Called on app startup to check whether a saved token is still valid
  /// — the account could've been deactivated from the dashboard since the
  /// last launch, or the token could be stale. Hits /me/, which requires a
  /// valid token to succeed.
  static Future<bool> tryAutoLogin() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/accounts/me/'),
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, response.body);
        return true;
      }
    } catch (_) {
      // No network / server unreachable at startup — fall through and
      // just show the login screen rather than crashing the app.
    }

    await logout();
    return false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Not signed in with Google, or already signed out. Nothing to do.
      }
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}