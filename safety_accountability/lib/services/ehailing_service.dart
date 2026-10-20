import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EhailingException implements Exception {
  final String message;
  EhailingException(this.message);
  @override
  String toString() => message;
}

class EhailingService {
  static Future<String> _token() async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw EhailingException('You need to be signed in to do this.');
    }
    return token;
  }

  // ---------------- Trips ----------------

  static Future<Map<String, dynamic>> createTrip({
    required String service,
    required String driverName,
    String vehicleReg = '',
    String vehicleModel = '',
    String vehicleColor = '',
    String pickupLocation = '',
    String destinationLocation = '',
    String verificationPin = '',
  }) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/trips/');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
            body: jsonEncode({
              'service': service,
              'driver_name': driverName,
              'vehicle_reg': vehicleReg,
              'vehicle_model': vehicleModel,
              'vehicle_color': vehicleColor,
              'pickup_location': pickupLocation,
              'destination_location': destinationLocation,
              'verification_pin': verificationPin,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> endTrip(int tripId) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/trips/$tripId/end/');
    try {
      final response = await http.post(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  // ---------------- Communities ----------------

  static Future<List<dynamic>> listCommunities() async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/communities/');
    try {
      final response = await http.get(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      return _handleList(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> createCommunity({required String name, required String area}) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/communities/');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
            body: jsonEncode({'name': name, 'area': area}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  static Future<void> joinCommunity(int id) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/communities/$id/join/');
    try {
      final response = await http.post(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      _handleEmpty(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  static Future<void> leaveCommunity(int id) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/communities/$id/leave/');
    try {
      final response = await http.post(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      _handleEmpty(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  static Future<List<dynamic>> listCommunityPosts(int communityId) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/communities/$communityId/posts/');
    try {
      final response = await http.get(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      return _handleList(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> createCommunityPost(int communityId, String message) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/communities/$communityId/posts/');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  // ---------------- Passenger logs ----------------

  static Future<Map<String, dynamic>> createPassengerLog({
    required String passengerName,
    String passengerPhone = '',
    String pickupLocation = '',
    String destinationLocation = '',
    int passengerCount = 1,
    String notes = '',
    File? photo,
    bool autoCheckIn = false,
  }) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/passenger-logs/');
    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Token $token'
        ..fields['passenger_name'] = passengerName
        ..fields['passenger_phone'] = passengerPhone
        ..fields['pickup_location'] = pickupLocation
        ..fields['destination_location'] = destinationLocation
        ..fields['passenger_count'] = passengerCount.toString()
        ..fields['notes'] = notes
        ..fields['auto_check_in'] = autoCheckIn.toString();
      if (photo != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
      }
      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamed);
      return _handleMap(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> dropOffPassengerLog(int id) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/passenger-logs/$id/drop-off/');
    try {
      final response = await http.post(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  // ---------------- Panic ----------------

  static Future<Map<String, dynamic>> triggerPanic({
    required String role,
    int? trip,
    int? passengerLog,
    int? community,
    double? latitude,
    double? longitude,
  }) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/panic/');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
            body: jsonEncode({
              'role': role,
              'trip': ?trip,
              'passenger_log': ?passengerLog,
              'community': ?community,
              'latitude': ?latitude,
              'longitude': ?longitude,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> panicStatus(int id) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/panic/$id/status/');
    try {
      final response = await http.get(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> panicResolve(int id) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/ehailing/panic/$id/resolve/');
    try {
      final response = await http.post(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on EhailingException {
      rethrow;
    } catch (_) {
      throw EhailingException('Could not reach the server.');
    }
  }

  // ---------------- internals ----------------

  static Map<String, dynamic> _handleMap(http.Response response) {
    _checkStatus(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static List<dynamic> _handleList(http.Response response) {
    _checkStatus(response);
    if (response.body.isEmpty) return [];
    final decoded = jsonDecode(response.body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['results'] is List) return decoded['results'] as List;
    return [];
  }

  static void _handleEmpty(http.Response response) {
    _checkStatus(response);
  }

  static void _checkStatus(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
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
    throw EhailingException(message);
  }
}