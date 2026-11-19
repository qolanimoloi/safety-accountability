import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_service.dart';
import '../services/contacts_service.dart';
import '../l10n/generated/app_localizations.dart';
import 'dart:typed_data';

class EmergencyType {
  final String value; // backend incident_type value
  final IconData icon;

  const EmergencyType({required this.value, required this.icon});
}

const List<EmergencyType> _emergencyTypes = [
  EmergencyType(value: 'break_in', icon: Icons.home_rounded),
  EmergencyType(value: 'being_followed', icon: Icons.visibility_rounded),
  EmergencyType(value: 'hijacking', icon: Icons.directions_car_rounded),
  EmergencyType(value: 'domestic_violence', icon: Icons.family_restroom_rounded),
  EmergencyType(value: 'medical_emergency', icon: Icons.medical_services_rounded),
  EmergencyType(value: 'fire', icon: Icons.local_fire_department_rounded),
  EmergencyType(value: 'assault', icon: Icons.personal_injury_rounded),
  EmergencyType(value: 'other', icon: Icons.warning_amber_rounded),
];

String _emergencyTypeLabel(BuildContext context, String value) {
  final l = AppLocalizations.of(context)!;
  switch (value) {
    case 'break_in':
      return l.incidentBreakIn;
    case 'being_followed':
      return l.incidentBeingFollowed;
    case 'hijacking':
      return l.incidentHijacking;
    case 'domestic_violence':
      return l.incidentDomesticViolence;
    case 'medical_emergency':
      return l.incidentMedicalEmergency;
    case 'fire':
      return l.incidentFire;
    case 'assault':
      return l.incidentAssault;
    default:
      return l.incidentOther;
  }
}

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  String? _selected; // stores the EmergencyType.value, not a display label
  List<Map<String, dynamic>> _incomingAlerts = [];
  Timer? _alertsTimer;

  @override
  void initState() {
    super.initState();
    _loadIncomingAlerts();
    _alertsTimer = Timer.periodic(const Duration(seconds: 12), (_) => _loadIncomingAlerts());
  }

  @override
  void dispose() {
    _alertsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadIncomingAlerts() async {
    try {
      final alerts = await ContactsService.incomingAlerts();
      if (!mounted) return;
      setState(() => _incomingAlerts = alerts);
    } on ContactsException {
      // Silent — this is a background check, not a user-triggered action.
    }
  }

  void _handleSelect(EmergencyType type) {
    if (_selected == type.value) {
      setState(() => _selected = null);
      return;
    }
    setState(() => _selected = type.value);
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: false,
      builder: (_) => _EmergencyPopup(
        type: type,
        onClose: () => setState(() => _selected = null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          if (_incomingAlerts.isNotEmpty) ...[
            ..._incomingAlerts.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _IncomingAlertCard(alert: a),
                )),
            const SizedBox(height: 8),
          ],
          Text(
            l.emergencyResponseTitle,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 6),
          Text(
            l.emergencyResponseSubtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 28),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _emergencyTypes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) {
              final type = _emergencyTypes[index];
              final isSelected = _selected == type.value;
              return _EmergencyCard(
                type: type,
                isSelected: isSelected,
                onTap: () => _handleSelect(type),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmergencyCard extends StatefulWidget {
  final EmergencyType type;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmergencyCard({required this.type, required this.isSelected, required this.onTap});

  @override
  State<_EmergencyCard> createState() => _EmergencyCardState();
}

class _EmergencyCardState extends State<_EmergencyCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    final label = _emergencyTypeLabel(context, widget.type.value);
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFFDC3545), Color(0xFFC82333)])
              : const LinearGradient(colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? const Color(0xFFDC3545) : const Color(0xFFDEE2E6), width: 2),
          boxShadow: [
            BoxShadow(
              color: selected ? const Color(0xFFDC3545).withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.06),
              blurRadius: selected ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (selected)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => Transform.scale(
                  scale: 1 + (_pulseController.value * 0.06),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 1 - _pulseController.value), width: 2),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.type.icon, size: 34, color: selected ? Colors.white : const Color(0xFF495057)),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: selected ? Colors.white : const Color(0xFF495057),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _PopupStage { sending, error, waiting, responded, overdue }

class _EmergencyPopup extends StatefulWidget {
  final EmergencyType type;
  final VoidCallback onClose;

  const _EmergencyPopup({required this.type, required this.onClose});

  @override
  State<_EmergencyPopup> createState() => _EmergencyPopupState();
}

class _EmergencyPopupState extends State<_EmergencyPopup> {
  _PopupStage _stage = _PopupStage.sending;
  String? _errorMessage;
  String? _reference;
  DateTime? _createdAt;
  int _secondsRemaining = 300;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _sendAlert();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendAlert() async {
    setState(() {
      _stage = _PopupStage.sending;
      _errorMessage = null;
    });

    double? lat;
    double? lng;
    try {
      lat = null;
      lng = null;
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
                if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          ).timeout(const Duration(seconds: 10));
          lat = double.parse(position.latitude.toStringAsFixed(6));
          lng = double.parse(position.longitude.toStringAsFixed(6));
        }
      }
    } catch (_) {
      // Location is best-effort — an emergency alert must still go out
      // even if GPS fails or permission is denied.
    }

    try {
      final result = await EmergencyService.trigger(
        incidentType: widget.type.value,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      setState(() {
        _reference = result['reference'] as String?;
        _createdAt = DateTime.tryParse(result['created_at']?.toString() ?? '');
        _secondsRemaining = (result['seconds_remaining'] as num?)?.toInt() ?? 300;
        _stage = _PopupStage.waiting;
      });
      _startPolling();
    } on EmergencyException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _PopupStage.error;
        _errorMessage = e.message;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_reference == null) return;
    try {
      final result = await EmergencyService.status(_reference!);
      if (!mounted) return;
      final status = result['status'] as String?;
      final isOverdue = result['is_overdue'] == true;
      final secondsRemaining = (result['seconds_remaining'] as num?)?.toInt() ?? 0;
      final responded = result['responded_at'] != null || status == 'responding' || status == 'resolved';

      setState(() {
        _secondsRemaining = secondsRemaining;
        if (responded) {
          _stage = _PopupStage.responded;
        } else if (isOverdue) {
          _stage = _PopupStage.overdue;
        } else {
          _stage = _PopupStage.waiting;
        }
      });

      if (responded || isOverdue) {
        _pollTimer?.cancel();
      }
    } on EmergencyException {
      // A single failed poll isn't worth surfacing — it'll just try again
      // on the next tick. Only the initial trigger failure is shown.
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadPONR() async {
    // The certificate text itself stays in English — it's a formal
    // document used for insurance/legal purposes, not everyday app UI.
    final doc = pw.Document();
    final createdAt = _createdAt ?? DateTime.now();
    final ref = _reference ?? 'UNKNOWN';
    final incidentLabel = _emergencyTypeLabel(context, widget.type.value);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text('SAFETY & ACCOUNTABILITY SYSTEMS',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(
              child: pw.Text('Official Emergency Response Documentation', style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text('PROOF OF NON-RESPONSE (PONR) CERTIFICATE',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Document Ref: $ref', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text('EMERGENCY INCIDENT DETAILS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Incident Type: $incidentLabel', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Timestamp Reported: $createdAt', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Location Data: Captured via device GPS at time of alert', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Response Protocol: Standard 5-minute emergency window', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 16),
            pw.Text('RESPONSE STATUS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('STATUS: NO OFFICIAL RESPONSE RECEIVED',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.red700, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('OFFICIAL CERTIFICATION STATEMENT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(
              'This document certifies that an emergency assistance request was formally submitted through '
              'the Safety & Accountability System. Despite proper protocol execution and system verification, '
              'no official response was provided within the designated 5-minute critical response window as '
              'mandated by standard emergency protocols.\n\n'
              'This certificate serves as official documentation of system engagement and the subsequent '
              'lack of timely emergency service response for insurance, legal, and administrative purposes.',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 24),
            pw.Text('AUTHORIZED SIGNATORY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Mr. QT Moloi', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Chief Executive Officer', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('Safety & Accountability Systems', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );

       final bytes = await doc.save();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _PonrViewerPage(bytes: bytes, fileName: 'PONR-Certificate-$ref.pdf')),
    );
  }

  Widget _buildBody() {
    final l = AppLocalizations.of(context)!;
    switch (_stage) {
      case _PopupStage.sending:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              const CircularProgressIndicator(color: Color(0xFFDC3545)),
              const SizedBox(height: 14),
              Text(l.sendingAlert, style: const TextStyle(fontSize: 14, color: Color(0xFF333333))),
            ],
          ),
        );

      case _PopupStage.error:
        return Column(
          children: [
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545), padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _sendAlert,
                child: Text(l.tryAgain, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );

      case _PopupStage.responded:
        return Column(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF28A745), size: 40),
            const SizedBox(height: 10),
            Text(
              l.adminResponded,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF28A745)),
            ),
            if (_reference != null) ...[
              const SizedBox(height: 6),
              Text(l.referenceLabel(_reference!), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        );

      case _PopupStage.overdue:
        return Column(
          children: [
            Text(
              l.noResponseWindow,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545), padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _downloadPONR,
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                label: Text(l.downloadPonr, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );

      case _PopupStage.waiting:
        return Column(
          children: [
            if (_reference != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(l.referenceLabel(_reference!), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFD7E14), padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: null,
                child: Text('⏱️ ${l.waitingForResponse(_formatTime(_secondsRemaining))}', style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final typeLabel = _emergencyTypeLabel(context, widget.type.value);
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFDC3545), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () {
                  widget.onClose();
                  Navigator.of(context).pop();
                },
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFFDC3545),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
            const Icon(Icons.shield_rounded, color: Color(0xFFDC3545), size: 34),
            const SizedBox(height: 10),
            Text(
              '🚨 ${l.emergencyTitle(typeLabel)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFDC3545)),
            ),
            const SizedBox(height: 12),
            Text(
              l.emergencyDispatchMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 24),
            _buildBody(),
          ],
        ),
      ),
    );
  }
}

class _IncomingAlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  const _IncomingAlertCard({required this.alert});

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
        final lat = double.tryParse('${alert['latitude'] ?? ''}');
    final lng = double.tryParse('${alert['longitude'] ?? ''}');
    final phone = alert['reporter_phone']?.toString();
    final name = alert['reporter_name']?.toString() ?? 'Someone';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFDC3545), Color(0xFFC82333)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFFDC3545).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.contactNeedsHelp(name),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${alert['incident_type_display'] ?? ''} · ${alert['status_display'] ?? ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (phone != null && phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _call(phone),
                  style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.15), foregroundColor: Colors.white),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: Text(l.callAction, style: const TextStyle(fontSize: 12)),
                ),
              if (lat != null && lng != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _openMap(lat, lng),
                  style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.15), foregroundColor: Colors.white),
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: Text(l.locationAction, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PonrViewerPage extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;

  const _PonrViewerPage({required this.bytes, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PONR Certificate'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: PdfPreview(
        build: (format) async => bytes,
        pdfFileName: fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}