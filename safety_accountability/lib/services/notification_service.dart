import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class NotificationServiceException implements Exception {
  final String message;
  NotificationServiceException(this.message);
  @override
  String toString() => message;
}

class NotificationService {
  static Uri _u(String path) => Uri.parse('${AuthService.baseUrl}$path');

  static Future<Map<String, String>> _authHeader() async {
    final token = await AuthService.getToken();
    return {if (token != null) 'Authorization': 'Token $token'};
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw NotificationServiceException('Could not load this right now (${res.statusCode}).');
  }

  static Future<List<Map<String, dynamic>>> list() async {
    final res = await http.get(_u('/api/notifications/'), headers: await _authHeader());
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  static Future<void> markAllRead() async {
    final res = await http.post(_u('/api/notifications/mark-all-read/'), headers: await _authHeader());
    _checkStatus(res);
  }

  static Future<void> markOneRead(int id) async {
    final res = await http.post(_u('/api/notifications/$id/read/'), headers: await _authHeader());
    _checkStatus(res);
  }
}