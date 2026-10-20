import 'dart:async';
import 'dart:io';
import '../widgets/location_field.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/events_service.dart';
import 'events_common.dart';

const List<String> _openStatuses = ['new', 'acknowledged', 'responding'];

Future<void> _openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Future<void> _call(String? phone) async {
  if (phone == null || phone.trim().isEmpty) return;
  await _openUrl('tel:${phone.trim()}');
}

Future<void> _openMaps(double? lat, double? lng, {String? query}) async {
  if (lat != null && lng != null) {
    await _openUrl('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  } else if (query != null && query.trim().isNotEmpty) {
    await _openUrl('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query.trim())}');
  }
}

Future<List<double>?> _currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    if (pos == null) return null;
    return [
      double.parse(pos.latitude.toStringAsFixed(6)),
      double.parse(pos.longitude.toStringAsFixed(6)),
    ];
  } catch (_) {
    return null;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1048576).toStringAsFixed(1)} MB';
}

IconData _evidenceIcon(String? kind) {
  switch (kind) {
    case 'image':
      return Icons.image_rounded;
    case 'video':
      return Icons.videocam_rounded;
    case 'audio':
      return Icons.mic_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

/// A file the person picked to attach, before it is sent.
class _Attachment {
  final String path;
  final String name;
  final int bytes;

  _Attachment(this.path, this.name, this.bytes);

  File get file => File(path);
  String get ext => name.contains('.') ? name.split('.').last.toLowerCase() : '';
  bool get isImage => const ['jpg', 'jpeg', 'png'].contains(ext);
  bool get isVideo => const ['mp4', 'mov'].contains(ext);
  bool get isAudio => const ['mp3', 'wav'].contains(ext);
}

class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;
  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Map<String, dynamic> _event;
  List<Map<String, dynamic>> _incidents = [];
  bool _busy = false;
  Timer? _poll;

  bool get _isHost => _event['is_host'] == true;
  bool get _attending => _event['attending'] == true;
  bool get _acceptsAlerts => _event['accepts_alerts'] == true;
  bool get _hasEnded => _event['has_ended'] == true;
  bool get _cancelled => _event['status'] == 'cancelled';
  int get _eventId => (_event['id'] as num).toInt();

  @override
  void initState() {
    super.initState();
    _event = Map<String, dynamic>.from(widget.event);
    _refresh();
    if (_isHost) {
      _poll = Timer.periodic(const Duration(seconds: 12), (_) => _loadIncidents());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refresh() async {
    try {
      final fresh = await EventsService.getEvent(_eventId);
      if (!mounted) return;
      setState(() => _event = fresh);
    } on EventsException {
      // Keep showing what we already have.
    }
    if (_isHost) await _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    try {
      final list = await EventsService.eventIncidents(_eventId);
      if (!mounted) return;
      setState(() => _incidents = list);
    } on EventsException {
      // Background refresh: stay quiet.
    }
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _event = updated);
      _toast(success);
    } on EventsException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelEvent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text('It will be marked as cancelled for everyone who joined.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel event', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => EventsService.cancelEvent(_eventId), 'Event cancelled.');
  }

  Future<void> _openReport({String? kind, bool anonymous = false}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _IncidentSheet(eventId: _eventId, initialKind: kind, initialAnonymous: anonymous),
    );
    if (result == null || !mounted) return;
    if (_isHost) _loadIncidents();
    await showDialog<void>(context: context, builder: (_) => _SentDialog(result: result));
  }

  Future<void> _openIncident(Map<String, dynamic> incident) async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _IncidentDetailSheet(incident: incident),
    );
    if (updated != null) _loadIncidents();
  }

  // ------------------------------------------------------------ widgets

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _infoRow(IconData icon, String text, {String? actionLabel, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF667EEA)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.35))),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel, style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _header() {
    final cat = eventCategoryOf(_event['category']?.toString());
    final count = (_event['attendee_count'] as num?)?.toInt() ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cat.icon, color: Colors.white, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _event['title']?.toString() ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(cat.label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text('$count attending', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _infoCard() {
    final start = parseDate(_event['start_at']);
    final end = parseDate(_event['end_at']);
    final lat = (_event['latitude'] as num?)?.toDouble();
    final lng = (_event['longitude'] as num?)?.toDouble();
    final venue = _event['venue_name']?.toString() ?? '';
    final address = _event['address']?.toString() ?? '';
    final securityName = _event['security_head_name']?.toString() ?? '';
    final securityPhone = _event['security_head_phone']?.toString() ?? '';
    final hostPhone = _event['host_phone']?.toString() ?? '';
    final expected = (_event['expected_attendance'] as num?)?.toInt();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.schedule_rounded, formatEventWhen(start, end)),
          _infoRow(
            Icons.place_rounded,
            address.isEmpty ? venue : '$venue, $address',
            actionLabel: (lat != null || address.isNotEmpty) ? 'Map' : null,
            onAction: () => _openMaps(lat, lng, query: '$venue $address'),
          ),
          if (expected != null) _infoRow(Icons.people_alt_rounded, 'About $expected guests expected'),
          _infoRow(
            Icons.person_rounded,
            'Hosted by ${_event['host_name'] ?? 'Unknown'}',
            actionLabel: hostPhone.isEmpty ? null : 'Call',
            onAction: () => _call(hostPhone),
          ),
          if (securityName.isNotEmpty || securityPhone.isNotEmpty)
            _infoRow(
              Icons.shield_rounded,
              'Head of security: ${securityName.isEmpty ? securityPhone : securityName}',
              actionLabel: securityPhone.isEmpty ? null : 'Call',
              onAction: () => _call(securityPhone),
            ),
          const Divider(height: 24),
          Text(_event['description']?.toString() ?? '', style: const TextStyle(fontSize: 13.5, height: 1.45)),
        ],
      ),
    );
  }

  Widget _attendButton() {
    if (_isHost) return const SizedBox.shrink();
    if (_hasEnded || _cancelled || _event['status'] != 'published') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        child: _attending
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _busy ? null : () => _run(() => EventsService.leave(_eventId), 'You left this event.'),
                icon: const Icon(Icons.logout_rounded),
                label: const Text("I'm no longer attending"),
              )
            : ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A745),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _busy ? null : () => _run(() => EventsService.attend(_eventId), "You're in. Safety tools are now unlocked."),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: const Text("I'm attending", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
      ),
    );
  }

  Widget _lockedTools() {
    return _card(
      child: const Row(
        children: [
          Icon(Icons.lock_rounded, color: Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap "I\'m attending" to unlock safety tools: report anonymously, trigger an SOS and send other alerts to the event\'s security team.',
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyTools() {
    final tiles = incidentKinds.where((k) => k.value != 'panic').toList();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: Color(0xFFDC3545)),
              SizedBox(width: 8),
              Text('Safety tools', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "These go straight to the event's security team and the platform admins. You can attach photos, video, audio or documents as evidence.",
            style: TextStyle(fontSize: 12.5, color: Colors.grey),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _openReport(kind: 'panic'),
              icon: const Icon(Icons.warning_rounded, color: Colors.white),
              label: const Text('SOS - I need help now', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _openReport(anonymous: true),
              icon: const Icon(Icons.visibility_off_rounded),
              label: const Text('Report anonymously'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Quick alerts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: tiles
                .map(
                  (k) => GestureDetector(
                    onTap: () => _openReport(kind: k.value),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(k.icon, size: 26, color: const Color(0xFF495057)),
                          const SizedBox(height: 6),
                          Text(
                            k.shortLabel,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF495057)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _hostConsole() {
    final openCount = _incidents.where((i) => _openStatuses.contains(i['status'])).length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Color(0xFF764BA2)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Safety alerts ($openCount open)',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(onPressed: _loadIncidents, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          const Text(
            'Alerts from your guests. This list refreshes by itself while this page is open.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_incidents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('No alerts. All clear.', style: TextStyle(color: Colors.grey))),
            )
          else
            ..._incidents.map((i) {
              final kind = incidentKindOf(i['kind']?.toString());
              final color = severityColor(i['severity']?.toString());
              final status = i['status']?.toString();
              final fileCount = (i['evidence'] as List?)?.length ?? 0;
              return GestureDetector(
                onTap: () => _openIncident(i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: color, width: 5)),
                  ),
                  child: Row(
                    children: [
                      Icon(kind.icon, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kind.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(
                              '${i['reporter_name'] ?? 'Anonymous'} · ${agoLabel(parseDate(i['created_at']))}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (fileCount > 0) ...[
                        const Icon(Icons.attach_file_rounded, size: 15, color: Colors.grey),
                        Text('$fileCount', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: incidentStatusColor(status).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (i['status_display'] ?? '').toString(),
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: incidentStatusColor(status)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAlert = (_attending || _isHost) && _acceptsAlerts;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Event'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          if (_isHost && _event['status'] == 'published' && !_hasEnded)
            IconButton(onPressed: _busy ? null : _cancelEvent, tooltip: 'Cancel event', icon: const Icon(Icons.event_busy_rounded)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(),
            if (_cancelled) _banner('This event was cancelled by the host.', Colors.grey, Icons.event_busy_rounded),
            if (_event['status'] == 'hidden') _banner('This event was hidden by an admin.', Colors.grey, Icons.visibility_off_rounded),
            if (_hasEnded && !_cancelled) _banner('This event has ended.', const Color(0xFFB38F00), Icons.flag_rounded),
            _infoCard(),
            _attendButton(),
            if (canAlert) _safetyTools() else if (!_isHost && !_attending && _event['status'] == 'published' && !_hasEnded) _lockedTools(),
            if (_isHost) _hostConsole(),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Bottom sheet: send an alert / report (with optional evidence)
// ======================================================================

class _IncidentSheet extends StatefulWidget {
  final int eventId;
  final String? initialKind;
  final bool initialAnonymous;

  const _IncidentSheet({required this.eventId, this.initialKind, this.initialAnonymous = false});

  @override
  State<_IncidentSheet> createState() => _IncidentSheetState();
}

class _IncidentSheetState extends State<_IncidentSheet> {
  static const int _maxFiles = 5;
  static const int _maxBytes = 50 * 1024 * 1024;
  static const Set<String> _allowedExt = {'jpg', 'jpeg', 'png', 'mp4', 'mov', 'mp3', 'wav', 'pdf', 'doc', 'docx'};

  final _description = TextEditingController();
  final _where = TextEditingController();
  final List<_Attachment> _files = [];
  late String _kind;
  late bool _anonymous;
  bool _attachLocation = true;
  bool _needsHelp = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind ?? 'suspicious';
    _anonymous = widget.initialAnonymous;
  }

  @override
  void dispose() {
    _description.dispose();
    _where.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- evidence

  void _addAttachment(String path, String name) {
    if (_files.length >= _maxFiles) {
      setState(() => _error = 'You can attach up to $_maxFiles files.');
      return;
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!_allowedExt.contains(ext)) {
      setState(() => _error = '"$name" is not a supported file type.');
      return;
    }
    final bytes = File(path).lengthSync();
    if (bytes > _maxBytes) {
      setState(() => _error = '"$name" is over the 50MB limit.');
      return;
    }
    if (_files.any((f) => f.path == path)) return;
    setState(() {
      _error = null;
      _files.add(_Attachment(path, name, bytes));
    });
  }

  Future<void> _takePhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
      if (x == null || !mounted) return;
      _addAttachment(x.path, x.name);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the camera.');
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1920);
      if (!mounted) return;
      for (final x in picked) {
        _addAttachment(x.path, x.name);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open your photos.');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (x == null || !mounted) return;
      _addAttachment(x.path, x.name);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open your videos.');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'mp4', 'mov'],
      );
      if (files.isEmpty || !mounted) return;
      for (final f in files) {
        final path = f.path;
        if (path != null) _addAttachment(path, f.name);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open your files.');
    }
  }

  void _removeAttachment(int index) {
    setState(() => _files.removeAt(index));
  }

  Widget _evidenceButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _sending ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
    );
  }

  Widget _attachmentTile(int index) {
    final a = _files[index];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: a.isImage
                ? Image.file(a.file, width: 44, height: 44, fit: BoxFit.cover)
                : Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFF667EEA).withValues(alpha: 0.12),
                    child: Icon(
                      a.isVideo ? Icons.videocam_rounded : (a.isAudio ? Icons.mic_rounded : Icons.insert_drive_file_rounded),
                      color: const Color(0xFF667EEA),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(_formatBytes(a.bytes), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            onPressed: _sending ? null : () => _removeAttachment(index),
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC3545)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- submit

  Future<void> _submit() async {
    if (_sending) return;
    if (_kind == 'other' && _description.text.trim().isEmpty) {
      setState(() => _error = 'Please describe what is happening.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });

    List<double>? loc;
    if (_attachLocation) loc = await _currentLocation();

    try {
      final result = await EventsService.reportIncident(
        widget.eventId,
        kind: _kind,
        description: _description.text.trim(),
        locationDescription: _where.text.trim(),
        latitude: loc?[0],
        longitude: loc?[1],
        isAnonymous: _anonymous,
        needsImmediateHelp: _needsHelp || _kind == 'panic',
        evidence: _files.map((f) => f.file).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } on EventsException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPanic = _kind == 'panic';
    final accent = isPanic ? const Color(0xFFDC3545) : const Color(0xFF667EEA);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(incidentKindOf(_kind).icon, color: accent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPanic ? 'Send an SOS' : (_anonymous ? 'Report anonymously' : 'Send an alert'),
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: accent),
                  ),
                ),
                IconButton(onPressed: _sending ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 6),
            if (isPanic)
              const Text(
                "Security gets this at once, marked critical. If someone's life is in danger, also call 10111.",
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: 'What is happening?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: incidentKinds
                    .where((k) => k.value != 'panic')
                    .map((k) => DropdownMenuItem(value: k.value, child: Text(k.label)))
                    .toList(),
                onChanged: (v) => setState(() => _kind = v ?? 'other'),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: isPanic ? 'Details (optional)' : 'Details${_kind == 'other' ? ' *' : ''}',
                hintText: 'What did you see? Who is involved?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
                       LocationField(
              controller: _where,
              label: 'Where exactly? (optional)',
              hint: 'e.g. near the main stage, gate 3',
              icon: Icons.place_outlined,
            ),
            const SizedBox(height: 16),
            const Text('Evidence (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            const Text('Photos, video, audio or documents. Up to 5 files, 50MB each.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _evidenceButton(Icons.photo_camera_outlined, 'Take photo', _takePhoto),
                _evidenceButton(Icons.photo_library_outlined, 'Photos', _pickPhotos),
                _evidenceButton(Icons.videocam_outlined, 'Video', _pickVideo),
                _evidenceButton(Icons.attach_file_rounded, 'Audio / file', _pickFiles),
              ],
            ),
            for (var i = 0; i < _files.length; i++) _attachmentTile(i),
            if (_anonymous && _files.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Your name is not saved and file names are not kept. Photos, videos and voices can still show people or places.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF856404), height: 1.35),
                ),
              ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              onChanged: _sending ? null : (v) => setState(() => _anonymous = v),
              title: const Text('Send anonymously', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Your name is not saved with this report. Security cannot see who sent it.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _attachLocation,
              onChanged: _sending ? null : (v) => setState(() => _attachLocation = v),
              title: const Text('Attach my location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Helps security find the spot quickly.', style: TextStyle(fontSize: 12)),
            ),
            if (!isPanic)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _needsHelp,
                onChanged: _sending ? null : (v) => setState(() => _needsHelp = v),
                title: const Text('Someone needs help right now', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Marks the alert as critical.', style: TextStyle(fontSize: 12)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFDC3545))),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _sending
                      ? (_files.isEmpty ? 'Sending...' : 'Uploading evidence...')
                      : (isPanic ? 'Send SOS now' : 'Send to security'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Dialog shown after an alert was sent
// ======================================================================

class _SentDialog extends StatefulWidget {
  final Map<String, dynamic> result;
  const _SentDialog({required this.result});

  @override
  State<_SentDialog> createState() => _SentDialogState();
}

class _SentDialogState extends State<_SentDialog> {
  String? _statusText;
  bool _checking = false;

  Future<void> _check() async {
    final ref = widget.result['reference']?.toString();
    if (ref == null) return;
    setState(() => _checking = true);
    try {
      final t = await EventsService.trackIncident(ref);
      if (!mounted) return;
      setState(() => _statusText = 'Status: ${t['status_display'] ?? 'Unknown'}');
    } on EventsException catch (e) {
      if (!mounted) return;
      setState(() => _statusText = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.result['reference']?.toString() ?? '';
    final files = (widget.result['evidence_count'] as num?)?.toInt() ?? 0;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF28A745)),
          SizedBox(width: 8),
          Text('Alert sent'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.result['message']?.toString() ?? 'Your alert was sent.'),
          if (files > 0) ...[
            const SizedBox(height: 6),
            Text('$files file${files == 1 ? '' : 's'} attached.', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          Text('Reference: $ref', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Keep this reference to check the status.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          if (_statusText != null) ...[
            const SizedBox(height: 10),
            Text(_statusText!, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF667EEA))),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : _check,
          child: _checking
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Check status'),
        ),
        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

// ======================================================================
// Host: respond to an alert
// ======================================================================

class _IncidentDetailSheet extends StatefulWidget {
  final Map<String, dynamic> incident;
  const _IncidentDetailSheet({required this.incident});

  @override
  State<_IncidentDetailSheet> createState() => _IncidentDetailSheetState();
}

class _IncidentDetailSheetState extends State<_IncidentDetailSheet> {
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _setStatus(String status) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await EventsService.setIncidentStatus(
        (widget.incident['id'] as num).toInt(),
        status,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on EventsException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  Widget _actionButton(String label, String status, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      onPressed: _saving ? null : () => _setStatus(status),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
    );
  }

  Widget _evidenceTile(Map<String, dynamic> e) {
    final kind = e['file_kind']?.toString();
    final url = e['url']?.toString() ?? '';
    final name = e['original_filename']?.toString() ?? '';
    final size = (e['size_bytes'] as num?)?.toInt() ?? 0;

    final Widget face;
    if (kind == 'image') {
      face = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 100,
            height: 100,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        ),
      );
    } else {
      face = Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(color: const Color(0xFF667EEA).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_evidenceIcon(kind), color: const Color(0xFF667EEA), size: 30),
            const SizedBox(height: 4),
            Text(
              kind == 'video' ? 'Video' : (kind == 'audio' ? 'Audio' : 'Document'),
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF667EEA), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openUrl(url),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            face,
            const SizedBox(height: 4),
            Text(
              name.isEmpty ? _formatBytes(size) : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.incident;
    final kind = incidentKindOf(i['kind']?.toString());
    final color = severityColor(i['severity']?.toString());
    final lat = (i['latitude'] as num?)?.toDouble();
    final lng = (i['longitude'] as num?)?.toDouble();
    final description = i['description']?.toString() ?? '';
    final where = i['location_description']?.toString() ?? '';
    final evidence = (i['evidence'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? <Map<String, dynamic>>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(kind.icon, color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(kind.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            Text(
              '${i['severity_display'] ?? ''} · ${i['status_display'] ?? ''} · ${i['reference'] ?? ''}',
              style: const TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text('From: ${i['reporter_name'] ?? 'Anonymous'}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Received ${agoLabel(parseDate(i['created_at']))}', style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            const SizedBox(height: 12),
            Text(description.isEmpty ? 'No details were given.' : description, style: const TextStyle(height: 1.4)),
            if (where.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Where: $where', style: const TextStyle(fontSize: 13)),
            ],
            if (lat != null && lng != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openMaps(lat, lng),
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('Open location in maps'),
                ),
              ),
            if (evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Evidence (${evidence.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('Tap a file to open it.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: evidence.map(_evidenceTile).toList()),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFDC3545))),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionButton('Acknowledge', 'acknowledged', const Color(0xFFB38F00)),
                _actionButton('Responding', 'responding', const Color(0xFF667EEA)),
                _actionButton('Resolved', 'resolved', const Color(0xFF28A745)),
                _actionButton('False alarm', 'false_alarm', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}