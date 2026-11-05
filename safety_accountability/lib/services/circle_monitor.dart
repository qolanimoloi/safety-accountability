import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'circles_service.dart';

enum CircleMonitorState {
  /// Nothing to watch (no circle has a curfew with a home, or a restricted place).
  idle,

  /// Watching, including while the app is in the background.
  running,

  /// Watching only while the app is open: "Allow all the time" is not granted.
  foregroundOnly,

  /// Location is switched off or permission was refused.
  blocked,
}

/// Checks the circle rules ON THIS PHONE:
///  - past curfew and away from home  -> tells the circle (once per night)
///  - inside a restricted place        -> tells the circle (server limits repeats)
/// The server only ever receives an alert when a rule is broken. It never receives
/// a constant trail of locations.
class CircleMonitor {
  static final ValueNotifier<CircleMonitorState> state = ValueNotifier(CircleMonitorState.idle);

  static List<Map<String, dynamic>> _rules = [];
  static StreamSubscription<Position>? _sub;
  static Timer? _tick;
  static Timer? _refreshTimer;
  static Position? _last;
  static bool _starting = false;
  static bool _evaluating = false;
  static final Set<String> _insideZones = {};

  static const _cacheKey = 'circle_monitor_rules_v1';

  static bool get _supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static bool _worthWatching(List<Map<String, dynamic>> rules) {
    for (final c in rules) {
      final curfew = c['curfew'] as Map?;
      final home = c['home'];
      final zones = c['zones'] as List? ?? [];
      if ((curfew?['enabled'] == true && home != null) || zones.isNotEmpty) return true;
    }
    return false;
  }

  /// Safe to call as often as you like (app start, opening Circles, after a rule changes).
  static Future<void> ensureRunning({bool forceRefresh = false}) async {
    if (!_supported || _starting) return;
    _starting = true;
    try {
      await _loadRules(forceRefresh: forceRefresh);
      if (!_worthWatching(_rules)) {
        await stop();
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        await _stopStreams();
        state.value = CircleMonitorState.blocked;
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        await _stopStreams();
        state.value = CircleMonitorState.blocked;
        return;
      }
      state.value = perm == LocationPermission.always ? CircleMonitorState.running : CircleMonitorState.foregroundOnly;

      _refreshTimer ??= Timer.periodic(const Duration(minutes: 15), (_) => ensureRunning(forceRefresh: true));
      if (_sub == null) {
        _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
          (p) {
            _last = p;
            _evaluate();
          },
          onError: (_) {},
          cancelOnError: false,
        );
      }
      _tick ??= Timer.periodic(const Duration(minutes: 3), (_) => _periodicCheck());
      _periodicCheck();
    } finally {
      _starting = false;
    }
  }

  static LocationSettings _settings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 30,
        intervalDuration: const Duration(minutes: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Circle safety checks are on',
          notificationText: 'Checking your circle curfew and restricted places on this phone.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 30);
  }

  static Future<void> stop() async {
    await _stopStreams();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    state.value = CircleMonitorState.idle;
  }

  static Future<void> _stopStreams() async {
    await _sub?.cancel();
    _sub = null;
    _tick?.cancel();
    _tick = null;
  }

  static Future<void> _loadRules({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _rules = await CirclesService.monitorRules();
      await prefs.setString(_cacheKey, jsonEncode(_rules));
    } catch (_) {
      if (_rules.isEmpty || forceRefresh) {
        final cached = prefs.getString(_cacheKey);
        if (cached != null) {
          try {
            _rules = List<Map<String, dynamic>>.from((jsonDecode(cached) as List).map((e) => Map<String, dynamic>.from(e as Map)));
          } catch (_) {}
        }
      }
    }
  }

  /// Called when the person signs out so another account does not inherit rules.
  static Future<void> clear() async {
    _rules = [];
    _insideZones.clear();
    _last = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await stop();
  }

  // ---------------------------------------------------------------- checks

  static Future<void> _periodicCheck() async {
    // A phone that is standing still sends no movement events, so look now and then
    // while a curfew is running.
    if (!_curfewRunningNow()) {
      if (_last != null) _evaluate();
      return;
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 25)),
      );
      _last = p;
    } catch (_) {}
    _evaluate();
  }

  static bool _curfewRunningNow() {
    final now = DateTime.now();
    for (final c in _rules) {
      if (_curfewNight(c, now) != null) return true;
    }
    return false;
  }

  static String _night(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int? _mins(String? hhmm) {
    if (hhmm == null) return null;
    final p = hhmm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// The night (date the curfew started) when this circle's curfew is running and the grace
  /// period is over. Otherwise null.
  static String? _curfewNight(Map<String, dynamic> c, DateTime now) {
    final cf = c['curfew'] as Map?;
    if (cf == null || cf['enabled'] != true || c['home'] == null) return null;
    final start = _mins(cf['start']?.toString());
    final end = _mins(cf['end']?.toString());
    if (start == null || end == null || start == end) return null;
    final grace = (cf['grace_minutes'] as num?)?.toInt() ?? 0;
    final days = ((cf['days'] as List?) ?? []).map((e) => (e as num).toInt()).toSet();
    final nowMin = now.hour * 60 + now.minute;

    DateTime? nightDate;
    int elapsed = 0;
    if (start < end) {
      if (nowMin >= start && nowMin < end) {
        nightDate = now;
        elapsed = nowMin - start;
      }
    } else if (nowMin >= start) {
      nightDate = now;
      elapsed = nowMin - start;
    } else if (nowMin < end) {
      nightDate = now.subtract(const Duration(days: 1));
      elapsed = nowMin + 1440 - start;
    }
    if (nightDate == null) return null;
    // Our days are Monday = 0 ... Sunday = 6. Dart's weekday is Monday = 1 ... Sunday = 7.
    if (!days.contains(nightDate.weekday - 1)) return null;
    if (elapsed < grace) return null;
    return _night(nightDate);
  }

  static Future<void> _evaluate() async {
    final pos = _last;
    if (pos == null || _evaluating) return;
    _evaluating = true;
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      for (final c in _rules) {
        final id = (c['circle_id'] as num).toInt();

        // ---- restricted places
        for (final z in (c['zones'] as List? ?? [])) {
          final zone = Map<String, dynamic>.from(z as Map);
          final zid = (zone['id'] as num).toInt();
          final key = '$id:$zid';
          final d = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, (zone['latitude'] as num).toDouble(), (zone['longitude'] as num).toDouble(),
          );
          final radius = (zone['radius_m'] as num).toDouble();
          if (d <= radius) {
            if (_insideZones.add(key)) {
              try {
                await CirclesService.postAlert(id, {
                  'kind': 'zone',
                  'zone_id': zid,
                  'latitude': pos.latitude,
                  'longitude': pos.longitude,
                });
              } catch (_) {
                _insideZones.remove(key); // try again on the next reading
              }
            }
          } else if (d > radius + 40) {
            _insideZones.remove(key);
          }
        }

        // ---- curfew
        final night = _curfewNight(c, now);
        if (night == null) continue;
        final home = Map<String, dynamic>.from(c['home'] as Map);
        final dHome = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, (home['latitude'] as num).toDouble(), (home['longitude'] as num).toDouble(),
        );
        final slack = pos.accuracy.isFinite ? pos.accuracy.clamp(0, 100).toDouble() : 0.0;
        final radius = (home['radius_m'] as num).toDouble();
        if (dHome <= radius + slack) continue; // home (or too close to be sure)
        // The reading must be recent, otherwise we may be judging an old position.
        if (now.difference(pos.timestamp).inMinutes > 10) continue;
        final sentKey = 'circle_curfew_sent_$id';
        if (prefs.getString(sentKey) == night) continue;
        try {
          await CirclesService.postAlert(id, {
            'kind': 'curfew',
            'night': night,
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          });
          await prefs.setString(sentKey, night);
        } on CircleException catch (e) {
          // "You are at home" / "no curfew" from the server: do not keep retrying all night.
          if (e.message.contains('home') || e.message.contains('curfew')) await prefs.setString(sentKey, night);
        } catch (_) {}
      }
    } finally {
      _evaluating = false;
    }
  }
}