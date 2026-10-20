import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EmergencyException implements Exception {
  final String message;
  EmergencyException(this.message);
  @override
  String toString() => message;
}

class EmergencyService {
  static Future<Map<String, dynamic>> trigger({
    required String incidentType,
    double? latitude,
    double? longitude,
    String locationDescription = '',
  }) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw EmergencyException('You need to be signed in to send an emergency alert.');
    }
    final uri = Uri.parse('${AuthService.baseUrl}/api/emergencies/trigger/');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
            body: jsonEncode({
              'incident_type': incidentType,
              'latitude': ?latitude,
              'longitude': ?longitude,
              'location_description': locationDescription,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handle(response);
    } on EmergencyException {
      rethrow;
    } catch (_) {
      throw EmergencyException('Could not reach the server. Check your connection and try again.');
    }
  }

  static Future<Map<String, dynamic>> status(String reference) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw EmergencyException('You need to be signed in to check this emergency.');
    }
    final uri = Uri.parse('${AuthService.baseUrl}/api/emergencies/$reference/status/');
    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Token $token'},
      ).timeout(const Duration(seconds: 15));
      return _handle(response);
    } on EmergencyException {
      rethrow;
    } catch (_) {
      throw EmergencyException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> resolve(String reference) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw EmergencyException('You need to be signed in to resolve this emergency.');
    }
    final uri = Uri.parse('${AuthService.baseUrl}/api/emergencies/$reference/resolve/');
    try {
      final response = await http.post(
        uri,
        headers: {'Authorization': 'Token $token'},
      ).timeout(const Duration(seconds: 15));
      return _handle(response);
    } on EmergencyException {
      rethrow;
    } catch (_) {
      throw EmergencyException('Could not reach the server.');
    }
  }

  static Map<String, dynamic> _handle(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    String message = 'Something went wrong. Please try again.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        if (decoded['detail'] != null) {
          message = decoded['detail'].toString();
        } else {
          final parts = <String>[];
          decoded.forEach((key, value) {
            parts.add(value is List ? value.join(' ') : value.toString());
          });
          if (parts.isNotEmpty) message = parts.join(' ');
        }
      }
    } catch (_) {}
    throw EmergencyException(message);
  }
}