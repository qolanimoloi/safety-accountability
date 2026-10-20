import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ActivityLogException implements Exception {
  final String message;
  ActivityLogException(this.message);
  @override
  String toString() => message;
}

class ActivityLogService {
  static Uri _u(String path) => Uri.parse('${AuthService.baseUrl}$path');

  static Future<Map<String, String>> _authHeader() async {
    final token = await AuthService.getToken();
    return {if (token != null) 'Authorization': 'Token $token'};
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw ActivityLogException(_extractError(res));
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

  static Future<List<Map<String, dynamic>>> listMine() async {
    final res = await http.get(_u('/api/activity-log/'), headers: await _authHeader());
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  /// Activities logged by people who have YOU saved as one of their
  /// emergency contacts. The admin team only sees one if a contact
  /// escalates it with [escalate].
  static Future<List<Map<String, dynamic>>> listSharedWithMe() async {
    final res = await http.get(_u('/api/activity-log/shared-with-me/'), headers: await _authHeader());
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  static Future<Map<String, dynamic>> create({
    required String activityType,
    required DateTime scheduledAt,
    DateTime? expectedReturnAt,
    required String location,
    String personName = '',
    File? personPhoto,
    String carReg = '',
    File? carPhoto,
    String notes = '',
  }) async {
    final request = http.MultipartRequest('POST', _u('/api/activity-log/'));
    request.headers.addAll(await _authHeader());
    request.fields['activity_type'] = activityType;
    // Send real instants (UTC) so the server never has to guess the phone's timezone.
    request.fields['scheduled_at'] = scheduledAt.toUtc().toIso8601String();
    if (expectedReturnAt != null) request.fields['expected_return_at'] = expectedReturnAt.toUtc().toIso8601String();
    request.fields['location'] = location;
    if (personName.isNotEmpty) request.fields['person_name'] = personName;
    if (carReg.isNotEmpty) request.fields['car_reg'] = carReg;
    if (notes.isNotEmpty) request.fields['notes'] = notes;
    if (personPhoto != null) request.files.add(await http.MultipartFile.fromPath('person_photo', personPhoto.path));
    if (carPhoto != null) request.files.add(await http.MultipartFile.fromPath('car_photo', carPhoto.path));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> delete(int id) async {
    final res = await http.delete(_u('/api/activity-log/$id/'), headers: await _authHeader());
    _checkStatus(res);
  }

  static Future<Map<String, dynamic>> markSafe(int id) async {
    final res = await http.post(_u('/api/activity-log/$id/mark-safe/'), headers: await _authHeader());
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// An emergency contact sends an overdue activity to the admin team.
  /// Fails with a readable message if the person is not overdue yet.
  static Future<Map<String, dynamic>> escalate(int id, {String note = ''}) async {
    try {
      final headers = {...await _authHeader(), 'Content-Type': 'application/json'};
      final res = await http
          .post(_u('/api/activity-log/$id/escalate/'), headers: headers, body: jsonEncode({'note': note}))
          .timeout(const Duration(seconds: 20));
      _checkStatus(res);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on ActivityLogException {
      rethrow;
    } catch (_) {
      throw ActivityLogException('Could not reach the server. Please try again.');
    }
  }
}