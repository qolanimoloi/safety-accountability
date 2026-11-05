import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';


class CommunityException implements Exception {
  final String message;
  CommunityException(this.message);
  @override
  String toString() => message;
}

class CommunityService {
  static Future<String> _token() async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw CommunityException('You need to be signed in to do this.');
    }
    return token;
  }

  static Future<List<dynamic>> listPosts({String? type, double? lat, double? lng}) async {
    final token = await _token();
    final params = <String, String>{};
    if (type != null && type != 'all') params['type'] = type;
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();
    final uri = Uri.parse('${AuthService.baseUrl}/api/community/posts/').replace(queryParameters: params.isEmpty ? null : params);
    try {
      final response = await http.get(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      return _handleList(response);
    } on CommunityException {
      rethrow;
    } catch (_) {
      throw CommunityException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> createPost({
    required String postType,
    required String category,
    required String content,
    String locationDescription = '',
    double? latitude,
    double? longitude,
    List<File>? media,
  }) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/community/posts/');
    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Token $token'
        ..fields['post_type'] = postType
        ..fields['category'] = category
        ..fields['content'] = content
        ..fields['location_description'] = locationDescription;
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();
      if (media != null) {
        for (final file in media) {
          request.files.add(await http.MultipartFile.fromPath('media', file.path));
        }
      }
      final streamed = await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);
      return _handleMap(response);
    } on CommunityException {
      rethrow;
    } catch (_) {
      throw CommunityException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> toggleLike(int postId) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/community/posts/$postId/like/');
    try {
      final response = await http.post(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on CommunityException {
      rethrow;
    } catch (_) {
      throw CommunityException('Could not reach the server.');
    }
  }

  static Future<List<dynamic>> listComments(int postId) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/community/posts/$postId/comments/');
    try {
      final response = await http.get(uri, headers: {'Authorization': 'Token $token'}).timeout(const Duration(seconds: 15));
      return _handleList(response);
    } on CommunityException {
      rethrow;
    } catch (_) {
      throw CommunityException('Could not reach the server.');
    }
  }

  /// Adds a comment: text, a sticker (its key), and/or one picture, GIF or short video.
  static Future<Map<String, dynamic>> createComment(
    int postId, {
    String content = '',
    String sticker = '',
    File? media,
  }) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/community/posts/$postId/comments/');
    try {
      if (media == null) {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
              body: jsonEncode({'content': content, 'sticker': sticker}),
            )
            .timeout(const Duration(seconds: 15));
        return _handleMap(response);
      }
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Token $token'
        ..fields['content'] = content
        ..fields['sticker'] = sticker;
      request.files.add(await http.MultipartFile.fromPath('media', media.path));
      final streamed = await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);
      return _handleMap(response);
    } on CommunityException {
      rethrow;
    } catch (_) {
      throw CommunityException('Could not reach the server.');
    }
  }

  /// React to a comment. Same emoji again removes it; a different one replaces it.
  /// Returns the comment's updated reactions.
  static Future<List<Map<String, dynamic>>> reactToComment(int commentId, String emoji) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/community/comments/$commentId/react/');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
            body: jsonEncode({'emoji': emoji}),
          )
          .timeout(const Duration(seconds: 15));
      final body = _handleMap(response);
      return List<Map<String, dynamic>>.from((body['reactions'] as List?) ?? const []);
    } on CommunityException {
      rethrow;
    } catch (_) {
      throw CommunityException('Could not reach the server.');
    }
  }

  /// target: 'community' (repost, with an optional [comment]),
  /// 'chat' (needs [conversationIds]) or 'contacts' (your emergency contacts).
  static Future<Map<String, dynamic>> sharePost(
    int postId, {
    required String target,
    String comment = '',
    List<int> conversationIds = const [],
  }) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/community/posts/$postId/share/');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
            body: jsonEncode({
              'target': target,
              if (comment.isNotEmpty) 'comment': comment,
              if (conversationIds.isNotEmpty) 'conversation_ids': conversationIds,
            }),
          )
          .timeout(const Duration(seconds: 30));
      return _handleMap(response);
    } on CommunityException {
      rethrow;
    } catch (_) {
      throw CommunityException('Could not reach the server.');
    }
  }

  static Future<void> reportPost(int postId, {required String reason, String details = ''}) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/community/posts/$postId/report/');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
            body: jsonEncode({'reason': reason, 'details': details}),
          )
          .timeout(const Duration(seconds: 15));
      _handleMap(response);
    } on CommunityException {
      rethrow;
    } catch (_) {
      throw CommunityException('Could not reach the server.');
    }
  }

  static Future<Map<String, dynamic>> quickAlert({String message = '', double? latitude, double? longitude}) async {
    final token = await _token();
    final uri = Uri.parse('${AuthService.baseUrl}/api/community/quick-alert/');
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json', 'Authorization': 'Token $token'},
            body: jsonEncode({
              'message': message,
              'latitude': ?latitude,
              'longitude': ?longitude,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handleMap(response);
    } on CommunityException {
      rethrow;
    } catch (_) {
      throw CommunityException('Could not reach the server.');
    }
  }

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
    throw CommunityException(message);
  }
}