import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/live_location_service.dart';

class LocationPage extends StatefulWidget {
  final LatLng? userLocation;

  const LocationPage({super.key, this.userLocation});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

enum _LocationIssue { servicesOff, permissionDenied, failed }

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

String _agoLabel(int seconds) {
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  return '${seconds ~/ 3600} h ago';
}

class _LocationPageState extends State<LocationPage> {
  final MapController _mapController = MapController();
  bool _showInfoCard = false;
  bool _loading = true;
  bool _usingFallback = false;
  bool _resolving = false;
  bool _deniedForever = false;
  // Which status message to show (resolved to the current language in build).
  _LocationIssue? _issue;

  // Emergency contacts who are sharing their live location with me.
  List<Map<String, dynamic>> _contactLocations = [];
  Map<String, dynamic>? _selectedContact;
  Timer? _contactsTimer;
  bool _loadingContacts = false;

  static const LatLng _fallback = LatLng(-25.7479, 29.4686); // Middelburg

  late LatLng _position;

  @override
  void initState() {
    super.initState();
    _position = widget.userLocation ?? _fallback;
    _resolveLocation(showLoading: false); // _loading is already true

    // If I switched sharing on earlier, carry on sending my position.
    LiveLocationService.refresh().catchError((_) {});

    _loadContactLocations();
    _contactsTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadContactLocations());
  }

  @override
  void didUpdateWidget(covariant LocationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLoc = widget.userLocation;
    if (newLoc != null && newLoc != oldWidget.userLocation) {
      setState(() {
        _position = newLoc;
        _usingFallback = false;
        _issue = null;
      });
      _safeMove(newLoc);
    }
  }

  @override
  void dispose() {
    _contactsTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _safeMove(LatLng target) {
    try {
      _mapController.move(target, 14);
    } catch (_) {
      // Map not ready yet; it will use initialCenter instead.
    }
  }

  void _fitAll() {
    final points = <LatLng>[_position];
    for (final c in _contactLocations) {
      final lat = (c['latitude'] as num?)?.toDouble();
      final lng = (c['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) points.add(LatLng(lat, lng));
    }
    if (points.length < 2) {
      _safeMove(_position);
      return;
    }
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(72),
          maxZoom: 16,
        ),
      );
    } catch (_) {
      // Map not ready yet.
    }
  }

  void _fail(_LocationIssue issue) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _usingFallback = true;
      _issue = issue;
    });
  }

  Future<void> _loadContactLocations() async {
    if (_loadingContacts) return;
    _loadingContacts = true;
    try {
      final list = await LiveLocationService.contactsLocations();
      if (!mounted) return;
      setState(() {
        _contactLocations = list;
        final selectedId = _selectedContact?['contact_id'];
        if (selectedId != null) {
          Map<String, dynamic>? refreshed;
          for (final c in list) {
            if (c['contact_id'] == selectedId) refreshed = c;
          }
          _selectedContact = refreshed; // closes the card if they stopped sharing
        }
      });
    } on LiveLocationException {
      // Silent: this is a background refresh, not something the user triggered.
    } finally {
      _loadingContacts = false;
    }
  }

  Future<void> _resolveLocation({bool showLoading = true}) async {
    if (_resolving) return;
    _resolving = true;

    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _issue = null;
      });
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        _fail(_LocationIssue.servicesOff);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _deniedForever = permission == LocationPermission.deniedForever;
        _fail(_LocationIssue.permissionDenied);
        return;
      }
      _deniedForever = false;

      Position? current;
      try {
        current = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } on TimeoutException {
        // GPS is slow (indoors or emulator): use the last known position.
        try {
          current = await Geolocator.getLastKnownPosition();
        } catch (_) {
          current = null;
        }
      }

      if (!mounted) return;
      if (current == null) {
        _fail(_LocationIssue.failed);
        return;
      }

      final here = LatLng(current.latitude, current.longitude);
      setState(() {
        _position = here;
        _usingFallback = false;
        _loading = false;
        _issue = null;
      });
      _safeMove(here);
    } catch (_) {
      _fail(_LocationIssue.failed);
    } finally {
      _resolving = false;
    }
  }

  Future<void> _retry() async {
    if (_deniedForever && _issue == _LocationIssue.permissionDenied) {
      await Geolocator.openAppSettings();
      return;
    }
    await _resolveLocation();
  }

  List<Marker> _contactMarkers() {
    final markers = <Marker>[];
    for (final c in _contactLocations) {
      final lat = (c['latitude'] as num?)?.toDouble();
      final lng = (c['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 56,
          height: 56,
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedContact = c;
              _showInfoCard = false;
            }),
            child: _ContactMarker(
              initials: _initialsOf(c['name']?.toString() ?? ''),
              stale: c['is_stale'] == true,
            ),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final issueText = switch (_issue) {
      _LocationIssue.servicesOff => l10n.locationServicesOff,
      _LocationIssue.permissionDenied => l10n.locationPermissionDenied,
      _LocationIssue.failed => l10n.locationFailed,
      null => null,
    };
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _position,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onTap: (_, _) {
              if (_selectedContact != null) setState(() => _selectedContact = null);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.safety_accountability',
              maxNativeZoom: 19,
            ),
            MarkerLayer(
              markers: [
                ..._contactMarkers(),
                Marker(
                  point: _position,
                  width: 46,
                  height: 46,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _showInfoCard = !_showInfoCard;
                      _selectedContact = null;
                    }),
                    child: Icon(
                      Icons.location_pin,
                      size: 46,
                      color: _usingFallback ? Colors.grey : const Color(0xFF007BFF),
                    ),
                  ),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        if (_loading)
          Positioned(
            top: 16,
            left: 16,
            right: 70,
            child: _StatusBanner(
              icon: Icons.my_location_rounded,
              text: l10n.gettingLocation,
              showSpinner: true,
            ),
          )
        else if (issueText != null)
          Positioned(
            top: 16,
            left: 16,
            right: 70,
            child: _StatusBanner(
              icon: Icons.location_off_rounded,
              text: issueText,
              onRetry: _retry,
            ),
          ),

        // Recenter / retry button, plus "show everyone" when contacts are sharing
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapButton(
                icon: Icons.my_location_rounded,
                onTap: () async {
                  if (_usingFallback) {
                    await _retry();
                  } else {
                    _safeMove(_position);
                  }
                },
              ),
              if (_contactLocations.isNotEmpty) ...[
                const SizedBox(height: 10),
                _MapButton(icon: Icons.groups_rounded, onTap: _fitAll),
              ],
            ],
          ),
        ),

        // Info card, appears when my own marker is tapped
        if (_showInfoCard)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _LocationInfoCard(position: _position, isFallback: _usingFallback),
          ),

        // Contact card, appears when a contact's marker is tapped
        if (_selectedContact != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _ContactInfoCard(
              contact: _selectedContact!,
              onClose: () => setState(() => _selectedContact = null),
              onCenter: () {
                final lat = (_selectedContact!['latitude'] as num?)?.toDouble();
                final lng = (_selectedContact!['longitude'] as num?)?.toDouble();
                if (lat != null && lng != null) _safeMove(LatLng(lat, lng));
              },
            ),
          ),
      ],
    );
  }
}

class _ContactMarker extends StatelessWidget {
  final String initials;
  final bool stale;

  const _ContactMarker({required this.initials, required this.stale});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: stale ? Colors.grey : const Color(0xFF28A745),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback onClose;
  final VoidCallback onCenter;

  const _ContactInfoCard({required this.contact, required this.onClose, required this.onCenter});

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final name = contact['name']?.toString() ?? 'Contact';
    final relationship = contact['relationship']?.toString() ?? '';
    final phone = contact['phone_number']?.toString();
    final stale = contact['is_stale'] == true;
    final seconds = (contact['seconds_ago'] as num?)?.toInt() ?? 0;
    final accent = stale ? Colors.grey : const Color(0xFF28A745);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent,
                child: Text(_initialsOf(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      relationship.isEmpty
                          ? 'Last seen ${_agoLabel(seconds)}'
                          : '$relationship · Last seen ${_agoLabel(seconds)}',
                      style: TextStyle(color: stale ? Colors.grey[600] : const Color(0xFF28A745), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20)),
            ],
          ),
          if (stale)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'This position may be out of date.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (phone != null && phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _call(phone),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF28A745)),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: const Text('Call', style: TextStyle(fontSize: 12.5)),
                ),
              TextButton.icon(
                onPressed: onCenter,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF007BFF)),
                icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                label: const Text('Center on map', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool showSpinner;
  final VoidCallback? onRetry;

  const _StatusBanner({
    required this.icon,
    required this.text,
    this.showSpinner = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (showSpinner)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF007BFF)),
              )
            else
              Icon(icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 12.5, color: Colors.grey[800])),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  AppLocalizations.of(context)!.retry,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF007BFF)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: const Color(0xFF007BFF), size: 22),
        ),
      ),
    );
  }
}

class _LocationInfoCard extends StatelessWidget {
  final LatLng position;
  final bool isFallback;

  const _LocationInfoCard({required this.position, this.isFallback = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: isFallback ? Colors.grey : const Color(0xFF007BFF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFallback ? AppLocalizations.of(context)!.defaultArea : AppLocalizations.of(context)!.youAreHere,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}