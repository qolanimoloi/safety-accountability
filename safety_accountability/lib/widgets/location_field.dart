import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PlaceResult {
  final String label;
  final double latitude;
  final double longitude;
  const PlaceResult(this.label, this.latitude, this.longitude);
}

class PlaceSearchException implements Exception {
  final String message;
  PlaceSearchException(this.message);
  @override
  String toString() => message;
}

/// Place search and reverse lookup using the free Photon service (OpenStreetMap data).
class PlaceSearchService {
  static const String _base = 'https://photon.komoot.io';

  // South Africa and its surroundings: minLon,minLat,maxLon,maxLat.
  // Change this if you want results from other countries too.
  static const String _bbox = '16.3,-35.0,33.1,-22.0';

  static const Map<String, String> _headers = {
    'User-Agent': 'SafetyAccountabilityApp/1.0',
    'Accept': 'application/json',
  };

  static String _label(Map<String, dynamic> p) {
    final parts = <String>[];
    void add(dynamic v) {
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty && !parts.contains(s)) parts.add(s);
    }

    add(p['name']);
    final street = p['street']?.toString().trim() ?? '';
    final house = p['housenumber']?.toString().trim() ?? '';
    if (street.isNotEmpty) add(house.isNotEmpty ? '$house $street' : street);
    add(p['district']);
    add(p['city']);
    add(p['state']);
    return parts.join(', ');
  }

  static List<PlaceResult> _parse(String body) {
    final decoded = jsonDecode(body);
    final features = decoded is Map ? decoded['features'] : null;
    if (features is! List) return [];
    final results = <PlaceResult>[];
    final seen = <String>{};
    for (final f in features) {
      if (f is! Map) continue;
      final coords = (f['geometry'] is Map) ? f['geometry']['coordinates'] : null;
      final props = f['properties'];
      if (coords is! List || coords.length < 2 || props is! Map) continue;
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final label = _label(Map<String, dynamic>.from(props));
      if (label.isEmpty || !seen.add(label)) continue;
      results.add(PlaceResult(label, lat, lon));
    }
    return results;
  }

  static Future<List<PlaceResult>> search(String query, {double? nearLat, double? nearLng}) async {
    final q = query.trim();
    if (q.length < 3) return [];
    final params = <String, String>{
      'q': q,
      'limit': '6',
      'lang': 'en',
      'bbox': _bbox,
      if (nearLat != null && nearLng != null) 'lat': nearLat.toString(),
      if (nearLat != null && nearLng != null) 'lon': nearLng.toString(),
    };
    final uri = Uri.parse('$_base/api').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw PlaceSearchException('Place search failed (${res.statusCode}).');
    return _parse(res.body);
  }

  /// Turns coordinates into an address. Returns null if the lookup fails.
  static Future<String?> reverse(double lat, double lng) async {
    try {
      final uri = Uri.parse('$_base/reverse').replace(
        queryParameters: {'lat': lat.toString(), 'lon': lng.toString(), 'lang': 'en', 'limit': '1'},
      );
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final results = _parse(res.body);
      return results.isEmpty ? null : results.first.label;
    } catch (_) {
      return null;
    }
  }
}

class CurrentLocation {
  /// Gets the phone's position, asking for permission if needed.
  /// Throws a [PlaceSearchException] with a message that is safe to show.
  static Future<Position> get() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw PlaceSearchException("Turn on your phone's location services first.");
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw PlaceSearchException('Location permission is needed to use your current location.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw PlaceSearchException('Location permission is blocked. Turn it on in your phone settings.');
    }
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
    } catch (_) {
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {
        pos = null;
      }
    }
    if (pos == null) throw PlaceSearchException('Could not get your location. Please try again.');
    return pos;
  }
}

/// A text field that suggests places as you type, with a
/// "Use my current location" button. Works with your own controller,
/// so [controller].text always holds the chosen address.
class LocationField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String hint;
  final IconData icon;

  /// Called when a suggestion is tapped or "Use my current location" finishes.
  final ValueChanged<PlaceResult>? onSelected;

  const LocationField({
    super.key,
    required this.controller,
    this.label,
    this.hint = 'Search for a place or address',
    this.icon = Icons.location_on_outlined,
    this.onSelected,
  });

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  Timer? _debounce;
  int _requestId = 0;
  bool _suppress = false;
  bool _searching = false;
  bool _locating = false;
  String _lastQuery = '';
  String? _message;
  List<PlaceResult> _results = [];
  double? _biasLat;
  double? _biasLng;

  @override
  void initState() {
    super.initState();
    _lastQuery = widget.controller.text.trim();
    widget.controller.addListener(_onTextChanged);
    _loadBias();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  Future<void> _loadBias() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p != null && mounted) {
        _biasLat = p.latitude;
        _biasLng = p.longitude;
      }
    } catch (_) {
      // No permission yet: search still works, just without nearby-first ordering.
    }
  }

  void _onTextChanged() {
    if (_suppress || !mounted) return;
    final text = widget.controller.text.trim();
    if (text == _lastQuery) return;
    _lastQuery = text;
    _debounce?.cancel();
    _requestId++;
    if (text.length < 3) {
      setState(() {
        _results = [];
        _message = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _message = null;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_requestId;
    try {
      final r = await PlaceSearchService.search(text, nearLat: _biasLat, nearLng: _biasLng);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = r;
        _searching = false;
        _message = r.isEmpty ? 'No matching places. You can keep typing the address yourself.' : null;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = [];
        _searching = false;
        _message = 'Place search is unavailable right now. You can type the address yourself.';
      });
    }
  }

  void _setText(String value) {
    _suppress = true;
    widget.controller.text = value;
    widget.controller.selection = TextSelection.collapsed(offset: value.length);
    _suppress = false;
    _lastQuery = value.trim();
  }

  void _select(PlaceResult p) {
    _debounce?.cancel();
    _requestId++;
    _setText(p.label);
    FocusScope.of(context).unfocus();
    setState(() {
      _results = [];
      _message = null;
      _searching = false;
    });
    widget.onSelected?.call(p);
  }

  Future<void> _useCurrent() async {
    if (_locating) return;
    _debounce?.cancel();
    _requestId++;
    FocusScope.of(context).unfocus();
    setState(() {
      _locating = true;
      _searching = false;
      _results = [];
      _message = null;
    });
    try {
      final pos = await CurrentLocation.get();
      final lat = double.parse(pos.latitude.toStringAsFixed(6));
      final lng = double.parse(pos.longitude.toStringAsFixed(6));
      final label = await PlaceSearchService.reverse(lat, lng) ?? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      if (!mounted) return;
      _setText(label);
      setState(() => _locating = false);
      widget.onSelected?.call(PlaceResult(label, lat, lng));
    } on PlaceSearchException catch (e) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _message = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _message = 'Could not get your location. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: widget.controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            prefixIcon: Icon(widget.icon, size: 20),
            hintText: widget.hint,
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              foregroundColor: const Color(0xFF007BFF),
              minimumSize: const Size(0, 32),
            ),
            onPressed: _locating ? null : _useCurrent,
            icon: _locating
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded, size: 18),
            label: Text(_locating ? 'Getting your location...' : 'Use my current location', style: const TextStyle(fontSize: 13)),
          ),
        ),
        if (_results.isNotEmpty)
          Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final r in _results)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, size: 20, color: Color(0xFF667EEA)),
                    title: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
                    onTap: () => _select(r),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('Results by Photon · © OpenStreetMap contributors', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_message!, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)),
          ),
      ],
    );
  }
}