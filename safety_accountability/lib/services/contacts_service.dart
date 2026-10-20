import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ContactsException implements Exception {
  final String message;
  ContactsException(this.message);
  @override
  String toString() => message;
}

class ContactsService {
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
    throw ContactsException(_extractError(res));
  }

  static String _extractError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        if (body['detail'] != null) return body['detail'].toString();
        if (body.keys.isNotEmpty) {
          final firstVal = body[body.keys.first];
          if (firstVal is List && firstVal.isNotEmpty) return firstVal.first.toString();
          return firstVal.toString();
        }
      }
    } catch (_) {}
    return 'Something went wrong (${res.statusCode}).';
  }

  /// Your saved emergency contacts. Each has `has_app`, `status`
  /// (pending / accepted / declined) and `is_protected`.
  static Future<List<Map<String, dynamic>>> listContacts() async {
    final res = await http.get(_u('/api/emergencies/contacts/'), headers: await _headers());
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  /// Sends a request. The person only counts as protecting you once they accept.
  static Future<Map<String, dynamic>> addContact({
    required String name,
    required String phoneNumber,
    required String relationship,
  }) async {
    final res = await http.post(
      _u('/api/emergencies/contacts/'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'phone_number': phoneNumber, 'relationship': relationship}),
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Sends a request to someone who already has an account (from chat or a community post).
  static Future<Map<String, dynamic>> addUserAsContact(int userId, {String relationship = 'Friend'}) async {
    final res = await http.post(
      _u('/api/emergencies/contacts/add-user/'),
      headers: await _headers(),
      body: jsonEncode({'user_id': userId, 'relationship': relationship}),
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteContact(int id) async {
    final res = await http.delete(_u('/api/emergencies/contacts/$id/'), headers: await _headers());
    _checkStatus(res);
  }

  /// Requests other people sent ME, waiting for me to accept or decline.
  static Future<List<Map<String, dynamic>>> incomingRequests() async {
    final res = await http.get(_u('/api/emergencies/contacts/requests/'), headers: await _headers());
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  static Future<Map<String, dynamic>> respondToRequest(int id, {required bool accept}) async {
    final res = await http.post(
      _u('/api/emergencies/contacts/$id/respond/'),
      headers: await _headers(),
      body: jsonEncode({'action': accept ? 'accept' : 'decline'}),
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Active emergencies from people who have the current user saved as
  /// one of THEIR emergency contacts. Polled from the Emergency page.
  static Future<List<Map<String, dynamic>>> incomingAlerts() async {
    final res = await http.get(_u('/api/emergencies/alerts-for-me/'), headers: await _headers());
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }
}