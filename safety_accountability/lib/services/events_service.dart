import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class EventsException implements Exception {
  final String message;
  EventsException(this.message);
  @override
  String toString() => message;
}

class EventsService {
  static Uri _u(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('${AuthService.baseUrl}$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null) throw EventsException('You need to be signed in to do this.');
    return {'Content-Type': 'application/json', 'Authorization': 'Token $token'};
  }

  static Future<http.Response> _send(Future<http.Response> Function(Map<String, String> headers) call) async {
    final headers = await _headers();
    try {
      return await call(headers).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw EventsException('Could not reach the server. Check your connection and try again.');
    }
  }

  static dynamic _decode(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = _decode(res.body);
    var message = 'Something went wrong (${res.statusCode}).';
    if (body is Map) {
      if (body['detail'] != null) {
        message = body['detail'].toString();
      } else if (body.isNotEmpty) {
        final parts = <String>[];
        body.forEach((key, value) => parts.add(value is List ? value.join(' ') : value.toString()));
        message = parts.join(' ');
      }
    }
    throw EventsException(message);
  }

  static Map<String, dynamic> _map(http.Response res) {
    _check(res);
    final body = _decode(res.body);
    return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _list(http.Response res) {
    _check(res);
    final body = _decode(res.body);
    if (body is List) {
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  // ------------------------------------------------------------ events

  static Future<List<Map<String, dynamic>>> listEvents() async {
    final res = await _send((h) => http.get(_u('/api/events/'), headers: h));
    return _list(res);
  }

  static Future<List<Map<String, dynamic>>> hostedEvents() async {
    final res = await _send((h) => http.get(_u('/api/events/hosting/'), headers: h));
    return _list(res);
  }

  static Future<Map<String, dynamic>> getEvent(int id) async {
    final res = await _send((h) => http.get(_u('/api/events/$id/'), headers: h));
    return _map(res);
  }

  static Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
    final res = await _send((h) => http.post(_u('/api/events/'), headers: h, body: jsonEncode(data)));
    return _map(res);
  }

  static Future<Map<String, dynamic>> cancelEvent(int id) async {
    final res = await _send((h) => http.post(_u('/api/events/$id/cancel/'), headers: h));
    return _map(res);
  }

  static Future<Map<String, dynamic>> attend(int id) async {
    final res = await _send((h) => http.post(_u('/api/events/$id/attend/'), headers: h));
    return _map(res);
  }

  static Future<Map<String, dynamic>> leave(int id) async {
    final res = await _send((h) => http.post(_u('/api/events/$id/leave/'), headers: h));
    return _map(res);
  }

  // --------------------------------------------------------- incidents

  /// Sends an alert or report, with optional evidence files (photos,
  /// videos, audio, documents) uploaded in the same request.
  static Future<Map<String, dynamic>> reportIncident(
    int eventId, {
    required String kind,
    String description = '',
    String locationDescription = '',
    double? latitude,
    double? longitude,
    bool isAnonymous = false,
    bool needsImmediateHelp = false,
    List<File> evidence = const [],
  }) async {
    final token = await AuthService.getToken();
    if (token == null) throw EventsException('You need to be signed in to do this.');
    try {
      final request = http.MultipartRequest('POST', _u('/api/events/$eventId/incidents/'))
        ..headers['Authorization'] = 'Token $token'
        ..fields['kind'] = kind
        ..fields['description'] = description
        ..fields['location_description'] = locationDescription
        ..fields['is_anonymous'] = isAnonymous.toString()
        ..fields['needs_immediate_help'] = needsImmediateHelp.toString();
      if (latitude != null && longitude != null) {
        request.fields['latitude'] = latitude.toString();
        request.fields['longitude'] = longitude.toString();
      }
      for (final f in evidence) {
        request.files.add(await http.MultipartFile.fromPath('evidence', f.path));
      }
      final streamed = await request.send().timeout(const Duration(seconds: 180));
      final res = await http.Response.fromStream(streamed);
      return _map(res);
    } on EventsException {
      rethrow;
    } catch (_) {
      throw EventsException('Could not send your report. Check your connection and try again.');
    }
  }

  /// Host only: every alert sent at this event.
  static Future<List<Map<String, dynamic>>> eventIncidents(int eventId) async {
    final res = await _send((h) => http.get(_u('/api/events/$eventId/incidents/'), headers: h));
    return _list(res);
  }

  static Future<Map<String, dynamic>> setIncidentStatus(int incidentId, String status, {String notes = ''}) async {
    final res = await _send(
      (h) => http.post(
        _u('/api/events/incidents/$incidentId/status/'),
        headers: h,
        body: jsonEncode({'status': status, 'notes': notes}),
      ),
    );
    return _map(res);
  }

  static Future<Map<String, dynamic>> trackIncident(String reference) async {
    final res = await _send(
      (h) => http.get(_u('/api/events/incidents/track/${Uri.encodeComponent(reference)}/'), headers: h),
    );
    return _map(res);
  }
}