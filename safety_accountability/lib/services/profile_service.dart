import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ProfileException implements Exception {
  final String message;
  ProfileException(this.message);
  @override
  String toString() => message;
}

/// What another person lets you see about them.
class PublicProfile {
  final int id;
  final String name;
  final String initials;
  final String? photoUrl;
  final bool isOfficial;
  final bool isMe;
  final DateTime? memberSince;
  final DateTime? lastSeen;
  final bool lastSeenHidden;
  final bool online;

  PublicProfile({
    required this.id,
    required this.name,
    required this.initials,
    required this.photoUrl,
    required this.isOfficial,
    required this.isMe,
    required this.memberSince,
    required this.lastSeen,
    required this.lastSeenHidden,
    required this.online,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        initials: j['initials']?.toString() ?? '?',
        photoUrl: j['photo_url']?.toString(),
        isOfficial: j['is_official'] == true,
        isMe: j['is_me'] == true,
        memberSince: DateTime.tryParse(j['member_since']?.toString() ?? ''),
        lastSeen: DateTime.tryParse(j['last_seen']?.toString() ?? '')?.toLocal(),
        lastSeenHidden: j['last_seen_hidden'] == true,
        online: j['online'] == true,
      );

  /// "Online", "Last seen today at 14:05", "Last seen yesterday at 09:30", ...
  String get lastSeenLabel {
    if (online) return 'Online';
    if (lastSeenHidden) return 'Last seen hidden';
    final t = lastSeen;
    if (t == null) return 'Not seen yet';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final clock = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final diffDays = today.difference(day).inDays;
    if (diffDays <= 0) return 'Last seen today at $clock';
    if (diffDays == 1) return 'Last seen yesterday at $clock';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Last seen ${t.day} ${months[t.month - 1]} ${t.year} at $clock';
  }
}

class ProfileService {
  static Uri _u(String path) => Uri.parse('${AuthService.baseUrl}$path');

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await AuthService.getToken();
    return {
      if (token != null) 'Authorization': 'Token $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  static String _error(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) return body['detail'].toString();
    } catch (_) {}
    if (res.statusCode == 404) return 'This person could not be found.';
    return 'Something went wrong (${res.statusCode}).';
  }

  static Future<PublicProfile> fetch(int userId) async {
    try {
      final res = await http.get(_u('/api/accounts/users/$userId/'), headers: await _headers()).timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) throw ProfileException(_error(res));
      return PublicProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } on ProfileException {
      rethrow;
    } catch (_) {
      throw ProfileException('Could not reach the server.');
    }
  }

  static Future<bool> getShowLastSeen() async {
    try {
      final res = await http.get(_u('/api/accounts/privacy/'), headers: await _headers()).timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) throw ProfileException(_error(res));
      return (jsonDecode(res.body) as Map)['show_last_seen'] == true;
    } on ProfileException {
      rethrow;
    } catch (_) {
      throw ProfileException('Could not reach the server.');
    }
  }

  static Future<bool> setShowLastSeen(bool value) async {
    try {
      final res = await http
          .post(
            _u('/api/accounts/privacy/'),
            headers: await _headers(json: true),
            body: jsonEncode({'show_last_seen': value}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) throw ProfileException(_error(res));
      return (jsonDecode(res.body) as Map)['show_last_seen'] == true;
    } on ProfileException {
      rethrow;
    } catch (_) {
      throw ProfileException('Could not reach the server.');
    }
  }
}