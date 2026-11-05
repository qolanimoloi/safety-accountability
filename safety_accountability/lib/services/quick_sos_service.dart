import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'auth_service.dart';

/// Talks to the native Android service that watches for 3 quick power-button
/// presses. Android only. iOS and browsers do not allow apps to see the
/// power button.
class QuickSosService {
  static const _channel = MethodChannel('safety/quick_sos');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<bool> isEnabled() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Re-starts the service if it was switched on but Android stopped it.
  static Future<void> ensureRunning() async {
    if (!supported) return;
    try {
      if (await isEnabled()) {
        await _channel.invokeMethod('start', {'baseUrl': AuthService.baseUrl});
      }
    } catch (_) {}
  }

  static Future<({bool ok, String? message, bool needsSettings})> enable() async {
    if (!supported) {
      return (ok: false, message: 'Quick SOS is only available on Android.', needsSettings: false);
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (ok: false, message: "Turn on your phone's location (GPS) first.", needsSettings: false);
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.whileInUse) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return (
          ok: false,
          message: 'Location permission is needed so admin can find you.',
          needsSettings: perm == LocationPermission.deniedForever,
        );
      }

      await _channel.invokeMethod('requestNotificationPermission');
      await _channel.invokeMethod('allowFullScreenAlert');
      final started = await _channel.invokeMethod<bool>('start', {'baseUrl': AuthService.baseUrl}) ?? false;
      if (!started) {
        return (ok: false, message: 'Could not start Quick SOS. Check location permission.', needsSettings: true);
      }
      await _channel.invokeMethod('batteryExemption');

      if (perm != LocationPermission.always) {
        return (
          ok: true,
          message: "Quick SOS is on. For it to work with the screen off, set Location to 'Allow all the time'.",
          needsSettings: true,
        );
      }
      return (
        ok: true,
        message: 'Quick SOS is on. Double-press the power button quickly. If your phone opens the camera or another shortcut instead, turn that shortcut off in Settings.',
        needsSettings: false,
      );
    } catch (_) {
      return (ok: false, message: 'Could not turn on Quick SOS. Please try again.', needsSettings: false);
    }
  }

  static Future<void> disable() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}