import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class LiveLocationException implements Exception {
  final String message;
  final bool sharingOff;
  LiveLocationException(this.message, {this.sharingOff = false});
  @override
  String toString() => message;
}

/// Opt-in live location sharing. While sharing is on and the app is open,
/// the phone's position is sent to Django every ~25 seconds. It stops
/// by itself when the timer ends, when sharing is switched off, or when
/// the user signs out.
class LiveLocationService {
  static const Duration _sendEvery = Duration(seconds: 25);

  /// Listened to by the sharing switch on the contacts page.
  static final ValueNotifier<bool> isSharing = ValueNotifier<bool>(false);
  static final ValueNotifier<DateTime?> sharingUntil = ValueNotifier<DateTime?>(null);

  static Timer? _timer;
  static bool _ticking = false;

  static Uri _u(String path) => Uri.parse('${AuthService.baseUrl}$path');

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw LiveLocationException('You need to be signed in to do this.');
    }
    return {'Content-Type': 'application/json', 'Authorization': 'Token $token'};
  }

  static Future<http.Response> _send(Future<http.Response> Function(Map<String, String> headers) call) async {
    final headers = await _headers();
    try {
      return await call(headers).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw LiveLocationException('Could not reach the server.');
    }
  }

  static Map<String, dynamic> _decodeMap(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  static void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = _decodeMap(res.body);
    String message = 'Something went wrong (${res.statusCode}).';
    if (body['detail'] != null) {
      message = body['detail'].toString();
    } else if (body.isNotEmpty) {
      final first = body[body.keys.first];
      message = first is List && first.isNotEmpty ? first.first.toString() : first.toString();
    }
    throw LiveLocationException(message, sharingOff: res.statusCode == 409);
  }

  // ---------------------------------------------------------------- state

  static void _applyState(Map<String, dynamic> state) {
    final on = state['is_sharing'] == true;
    isSharing.value = on;
    sharingUntil.value = DateTime.tryParse(state['sharing_until']?.toString() ?? '')?.toLocal();
    if (on) {
      final wasRunning = _timer != null;
      _timer ??= Timer.periodic(_sendEvery, (_) => _tick());
      if (!wasRunning) unawaited(_tick());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Reads the saved state from Django and starts/stops sending accordingly.
  static Future<void> refresh() async {
    final res = await _send((h) => http.get(_u('/api/emergencies/live/me/'), headers: h));
    _check(res);
    _applyState(_decodeMap(res.body));
  }

  static Future<void> _ensurePermission() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw LiveLocationException("Turn on your phone's location services to share your location.");
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw LiveLocationException('Location permission is needed to share your location.');
    }
  }

  /// Switch sharing on (optionally for [durationMinutes]) or off.
  static Future<void> setSharing({required bool enabled, int? durationMinutes}) async {
    if (enabled) await _ensurePermission();
    final res = await _send(
      (h) => http.post(
        _u('/api/emergencies/live/me/'),
        headers: h,
        body: jsonEncode({
          'sharing': enabled,
          'duration_minutes': ?durationMinutes,
        }),
      ),
    );
    _check(res);
    _applyState(_decodeMap(res.body));
  }

  // ------------------------------------------------------------- sending

  static Future<void> _tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        // Signed out: stop quietly.
        _applyState({'is_sharing': false});
        return;
      }

      final until = sharingUntil.value;
      if (until != null && DateTime.now().isAfter(until)) {
        await refresh(); // the server switches it off and we stop
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final res = await _send(
        (h) => http.post(
          _u('/api/emergencies/live/update/'),
          headers: h,
          body: jsonEncode({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy_m': position.accuracy,
          }),
        ),
      );
      _check(res);
    } on LiveLocationException catch (e) {
      if (e.sharingOff) _applyState({'is_sharing': false});
      // Any other error: try again on the next tick.
    } catch (_) {
      // GPS timeout etc.: try again on the next tick.
    } finally {
      _ticking = false;
    }
  }

  // -------------------------------------------------------------- reading

  /// Contacts I saved who are currently sharing their location with me.
  static Future<List<Map<String, dynamic>>> contactsLocations() async {
    final res = await _send((h) => http.get(_u('/api/emergencies/live/contacts/'), headers: h));
    _check(res);
    final decoded = jsonDecode(res.body);
    if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
    return [];
  }
}