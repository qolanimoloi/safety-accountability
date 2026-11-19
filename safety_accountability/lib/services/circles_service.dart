import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class CircleException implements Exception {
  final String message;
  CircleException(this.message);
  @override
  String toString() => message;
}

/// One kind of circle. [leaderOnly] circles let only leaders set rules;
/// the others need the group to agree.
class CircleKind {
  final String key;
  final String label;
  final IconData icon;
  final String blurb;
  final bool leaderOnly;
  const CircleKind(this.key, this.label, this.icon, this.blurb, this.leaderOnly);
}

const List<CircleKind> kCircleKinds = [
  CircleKind('family', 'Family', Icons.family_restroom_rounded, 'Parents set the rules for the family.', true),
  CircleKind('children', 'Children', Icons.child_care_rounded, 'Parents set a curfew and keep children away from unsafe places.', true),
  CircleKind('friends', 'Friend group', Icons.diversity_3_rounded, 'Anyone can suggest a rule. The group votes.', false),
  CircleKind('roommates', 'Roommates', Icons.home_work_rounded, 'Look out for each other at home. Rules are agreed together.', false),
  CircleKind('partners', 'Partners', Icons.favorite_rounded, 'Two people, one agreement.', false),
  CircleKind('colleagues', 'Colleagues', Icons.work_rounded, 'For people who work late or travel together.', false),
  CircleKind('neighbours', 'Neighbours', Icons.holiday_village_rounded, 'A street or complex watching out together.', false),
  CircleKind('students', 'Students', Icons.school_rounded, 'Campus friends, res and study groups.', false),
  CircleKind('travel', 'Travel group', Icons.luggage_rounded, 'Keep a trip together safe.', false),
  CircleKind('custom', 'Custom', Icons.tune_rounded, 'Your own kind of circle. You choose how rules are set.', false),
];

CircleKind circleKindOf(String key) =>
    kCircleKinds.firstWhere((k) => k.key == key, orElse: () => kCircleKinds.last);

class CirclesService {
  static Uri _u(String path) => Uri.parse('${AuthService.baseUrl}$path');

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  static String _error(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        if (body['detail'] != null) return body['detail'].toString();
        if (body.isNotEmpty) {
          final v = body[body.keys.first];
          if (v is List && v.isNotEmpty) return v.first.toString();
          return v.toString();
        }
      }
    } catch (_) {}
    return 'Something went wrong (${res.statusCode}).';
  }

  static dynamic _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) throw CircleException(_error(res));
    if (res.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(res.body);
  }

  static Future<dynamic> _send(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      final h = await _headers();
      final uri = _u(path);
      final encoded = body == null ? null : jsonEncode(body);
      late http.Response res;
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: h).timeout(const Duration(seconds: 30));
          break;
        case 'POST':
          res = await http.post(uri, headers: h, body: encoded ?? '{}').timeout(const Duration(seconds: 30));
          break;
        case 'PUT':
          res = await http.put(uri, headers: h, body: encoded ?? '{}').timeout(const Duration(seconds: 30));
          break;
        case 'PATCH':
          res = await http.patch(uri, headers: h, body: encoded ?? '{}').timeout(const Duration(seconds: 30));
          break;
        default:
          res = await http.delete(uri, headers: h).timeout(const Duration(seconds: 30));
      }
      return _decode(res);
    } on CircleException {
      rethrow;
    } catch (_) {
      throw CircleException('Could not reach the server. Check your connection and try again.');
    }
  }

  static Future<List<Map<String, dynamic>>> list() async =>
      List<Map<String, dynamic>>.from(await _send('GET', '/api/circles/') as List);

  static Future<Map<String, dynamic>> create(String name, String kind, {String? rulesMode}) async =>
      Map<String, dynamic>.from(await _send('POST', '/api/circles/', {
        'name': name,
        'kind': kind,
        'rules_mode': ?rulesMode,
      }) as Map);

  static Future<Map<String, dynamic>> get(int id) async =>
      Map<String, dynamic>.from(await _send('GET', '/api/circles/$id/') as Map);

  static Future<Map<String, dynamic>> rename(int id, String name) async =>
      Map<String, dynamic>.from(await _send('PATCH', '/api/circles/$id/', {'name': name}) as Map);

  static Future<void> delete(int id) => _send('DELETE', '/api/circles/$id/');

  static Future<void> invite(int id, int userId) => _send('POST', '/api/circles/$id/invite/', {'user_id': userId});

  static Future<void> respond(int id, {required bool accept}) =>
      _send('POST', '/api/circles/$id/respond/', {'action': accept ? 'accept' : 'decline'});

  static Future<void> leave(int id) => _send('POST', '/api/circles/$id/leave/');

  static Future<void> removeMember(int id, int userId) => _send('POST', '/api/circles/$id/members/$userId/remove/');

  static Future<void> promote(int id, int userId) => _send('POST', '/api/circles/$id/members/$userId/promote/');

  static Future<void> setHome(int id, double lat, double lng, int radius) =>
      _send('POST', '/api/circles/$id/home/', {'latitude': lat, 'longitude': lng, 'radius_m': radius});

  static Future<void> clearHome(int id) => _send('DELETE', '/api/circles/$id/home/');

  /// Returns {applied: bool, proposal_status?: String}. In a vote circle this is a proposal.
  static Future<Map<String, dynamic>> setCurfew(int id, Map<String, dynamic> curfew) async =>
      Map<String, dynamic>.from(await _send('PUT', '/api/circles/$id/curfew/', curfew) as Map);

  static Future<Map<String, dynamic>> addZone(int id, String name, double lat, double lng, int radius) async =>
      Map<String, dynamic>.from(await _send('POST', '/api/circles/$id/zones/', {
        'name': name,
        'latitude': lat,
        'longitude': lng,
        'radius_m': radius,
      }) as Map);

  static Future<Map<String, dynamic>> removeZone(int id, int zoneId) async =>
      Map<String, dynamic>.from(await _send('DELETE', '/api/circles/$id/zones/$zoneId/') as Map);

  static Future<List<Map<String, dynamic>>> proposals(int id) async =>
      List<Map<String, dynamic>>.from(await _send('GET', '/api/circles/$id/proposals/') as List);

  static Future<void> vote(int proposalId, bool agree) =>
      _send('POST', '/api/circles/proposals/$proposalId/vote/', {'agree': agree});

  static Future<List<Map<String, dynamic>>> alerts(int id) async =>
      List<Map<String, dynamic>>.from(await _send('GET', '/api/circles/$id/alerts/') as List);

  /// Everything this phone needs to check the rules on its own.
  static Future<List<Map<String, dynamic>>> monitorRules() async =>
      List<Map<String, dynamic>>.from(await _send('GET', '/api/circles/monitor/') as List);

  /// Returns true when a new alert was raised (false when it was already raised).
  static Future<bool> postAlert(int id, Map<String, dynamic> body) async {
    final r = await _send('POST', '/api/circles/$id/alerts/', body) as Map;
    return r['duplicate'] != true;
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    final res = await _send('GET', '/api/chat/users/search/?q=${Uri.encodeQueryComponent(q)}');
    return List<Map<String, dynamic>>.from(res as List);
  }
}