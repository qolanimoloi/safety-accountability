import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ChatException implements Exception {
  final String message;
  ChatException(this.message);
  @override
  String toString() => message;
}

class ChatService {
  static Uri _u(String path) => Uri.parse('${AuthService.baseUrl}$path');

  static Future<Map<String, String>> _authHeader() async {
    final token = await AuthService.getToken();
    return {if (token != null) 'Authorization': 'Token $token'};
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw ChatException(_extractError(res));
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

  static Future<List<Map<String, dynamic>>> listConversations() async {
    final res = await http.get(_u('/api/chat/conversations/'), headers: await _authHeader());
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  static Future<Map<String, dynamic>> createConversation({
    required List<int> memberIds,
    bool isGroup = false,
    String name = '',
  }) async {
    final res = await http.post(
      _u('/api/chat/conversations/'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'member_ids': memberIds, 'is_group': isGroup, 'name': name}),
    );
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final res = await http.get(_u('/api/chat/users/search/?q=${Uri.encodeQueryComponent(query)}'), headers: await _authHeader());
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  static Future<List<Map<String, dynamic>>> listMessages(int conversationId, {int? afterId}) async {
    final path = afterId == null
        ? '/api/chat/conversations/$conversationId/messages/'
        : '/api/chat/conversations/$conversationId/messages/?after_id=$afterId';
    final res = await http.get(_u(path), headers: await _authHeader());
    _checkStatus(res);
    return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
  }

  /// Sends text, a sticker, files, or a mix. A sticker is just its key (see stickers.dart).
  static Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    String text = '',
    String sticker = '',
    List<File> media = const [],
  }) async {
    final request = http.MultipartRequest('POST', _u('/api/chat/conversations/$conversationId/messages/'));
    request.headers.addAll(await _authHeader());
    if (text.isNotEmpty) request.fields['text'] = text;
    if (sticker.isNotEmpty) request.fields['sticker'] = sticker;
    for (final file in media) {
      request.files.add(await http.MultipartFile.fromPath('media', file.path));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> markRead(int conversationId) async {
    final res = await http.post(_u('/api/chat/conversations/$conversationId/read/'), headers: await _authHeader());
    _checkStatus(res);
  }

  /// React to a message. The same emoji again removes it; a different one replaces it.
  /// Returns the message's updated reactions.
  static Future<List<Map<String, dynamic>>> reactToMessage(int messageId, String emoji) async {
    final res = await http.post(
      _u('/api/chat/messages/$messageId/react/'),
      headers: {...await _authHeader(), 'Content-Type': 'application/json'},
      body: jsonEncode({'emoji': emoji}),
    );
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from((body['reactions'] as List?) ?? const []);
  }

  /// {messageId: reactions} for the latest messages that have reactions.
  static Future<Map<int, List<Map<String, dynamic>>>> listReactions(int conversationId) async {
    final res = await http.get(_u('/api/chat/conversations/$conversationId/reactions/'), headers: await _authHeader());
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final out = <int, List<Map<String, dynamic>>>{};
    body.forEach((key, value) {
      final id = int.tryParse(key);
      if (id != null && value is List) {
        out[id] = List<Map<String, dynamic>>.from(value);
      }
    });
    return out;
  }

  /// Sets the group picture. Returns the updated conversation.
  static Future<Map<String, dynamic>> setGroupIcon(int conversationId, File picture) async {
    final request = http.MultipartRequest('POST', _u('/api/chat/conversations/$conversationId/icon/'));
    request.headers.addAll(await _authHeader());
    request.files.add(await http.MultipartFile.fromPath('icon', picture.path));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> removeGroupIcon(int conversationId) async {
    final res = await http.delete(_u('/api/chat/conversations/$conversationId/icon/'), headers: await _authHeader());
    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}