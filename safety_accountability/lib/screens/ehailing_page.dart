import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import '../l10n/generated/app_localizations.dart';
import '../services/contacts_service.dart';
import '../services/ehailing_service.dart';
import '../widgets/location_field.dart';

// ===== E-Hailing services available in South Africa =====
class EhailService {
  final String name;
  final String value; // backend Trip.service value
  final IconData icon;
  final Color color;
  const EhailService({required this.name, required this.value, required this.icon, required this.color});
}

const List<EhailService> _services = [
  EhailService(name: 'Uber', value: 'uber', color: Color(0xFF000000), icon: Icons.local_taxi_rounded),
  EhailService(name: 'Bolt', value: 'bolt', color: Color(0xFF34D186), icon: Icons.electric_bolt_rounded),
  EhailService(name: 'Maxim', value: 'maxim', color: Color(0xFFFFD200), icon: Icons.directions_car_filled_rounded),
  EhailService(name: 'InDriver', value: 'indriver', color: Color(0xFF26C96B), icon: Icons.car_rental_rounded),
  EhailService(name: 'DiDi', value: 'didi', color: Color(0xFFFF7D00), icon: Icons.local_shipping_rounded),
];

String _timeAgo(AppLocalizations l10n, DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
  return l10n.daysAgo(diff.inDays);
}

// ===== Shared real panic-alert flow (used by both passenger & driver views) =====
enum _PanicStage { idle, sending, error, waiting, responded, overdue }

class _PanicFlow {
  final VoidCallback onUpdate;
  _PanicFlow({required this.onUpdate});

  _PanicStage stage = _PanicStage.idle;
  int? panicId;
  String? errorMessage;
  int secondsRemaining = 10;
  Timer? _pollTimer;

  bool get isActive => stage != _PanicStage.idle;

  Future<void> trigger({required String role, int? trip, int? passengerLog, int? community}) async {
    stage = _PanicStage.sending;
    errorMessage = null;
    onUpdate();

    double? lat;
    double? lng;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
      // Location is best-effort — the alert must still go out without it.
    }

    try {
      final result = await EhailingService.triggerPanic(
        role: role,
        trip: trip,
        passengerLog: passengerLog,
        community: community,
        latitude: lat,
        longitude: lng,
      );
      panicId = result['id'] as int?;
      secondsRemaining = (result['seconds_remaining'] as num?)?.toInt() ?? 10;
      stage = _PanicStage.waiting;
      onUpdate();
      _startPolling();
    } on EhailingException catch (e) {
      stage = _PanicStage.error;
      errorMessage = e.message;
      onUpdate();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    if (panicId == null) return;
    try {
      final result = await EhailingService.panicStatus(panicId!);
      final status = result['status'] as String?;
      final isOverdue = result['is_overdue'] == true;
      secondsRemaining = (result['seconds_remaining'] as num?)?.toInt() ?? 0;
      final responded = status == 'responding' || status == 'resolved';
      if (responded) {
        stage = _PanicStage.responded;
        _pollTimer?.cancel();
      } else if (isOverdue) {
        stage = _PanicStage.overdue;
        _pollTimer?.cancel();
      } else {
        stage = _PanicStage.waiting;
      }
      onUpdate();
    } catch (_) {
      // A single failed poll just tries again on the next tick.
    }
  }

  Future<void> resolveSafe() async {
    if (panicId != null) {
      try {
        await EhailingService.panicResolve(panicId!);
      } catch (_) {}
    }
    reset();
  }

  void reset() {
    _pollTimer?.cancel();
    stage = _PanicStage.idle;
    panicId = null;
    errorMessage = null;
    onUpdate();
  }

  void dispose() {
    _pollTimer?.cancel();
  }
}

Widget buildPanicActiveScreen({
  required AppLocalizations l10n,
  required _PanicFlow flow,
  required String contextLabel, // e.g. "Trip details attached", "Driver community notified"
}) {
  Widget body;
  switch (flow.stage) {
    case _PanicStage.sending:
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 14),
            Text(l10n.sendingAlert, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      );
      break;
    case _PanicStage.error:
      body = Column(
        children: [
          Text(
            flow.errorMessage ?? l10n.somethingWentWrong,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: flow.reset,
              child: Text(l10n.close, style: const TextStyle(color: Color(0xFFDC3545))),
            ),
          ),
        ],
      );
      break;
    case _PanicStage.responded:
      body = Column(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white, size: 50),
          const SizedBox(height: 12),
          Text(l10n.adminResponded, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: flow.reset,
              child: Text(l10n.close),
            ),
          ),
        ],
      );
      break;
    case _PanicStage.overdue:
    case _PanicStage.waiting:
    case _PanicStage.idle:
      body = Column(
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 60),
          const SizedBox(height: 16),
          Text(l10n.panicAlertActive, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            flow.stage == _PanicStage.overdue
                ? l10n.noResponseYet
                : l10n.waitingForResponse('${flow.secondsRemaining}s'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PanicStatusRow(icon: Icons.location_on_rounded, label: l10n.liveLocationShared),
                _PanicStatusRow(icon: Icons.local_police_rounded, label: l10n.adminNotified),
                _PanicStatusRow(icon: Icons.info_rounded, label: contextLabel),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: flow.resolveSafe,
              child: Text(l10n.imSafeCancel),
            ),
          ),
        ],
      );
  }

  return Container(
    color: const Color(0xFFDC3545),
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 30),
        body,
      ],
    ),
  );
}

class _PanicStatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PanicStatusRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF28A745), size: 18),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class EhailingPage extends StatefulWidget {
  const EhailingPage({super.key});

  @override
  State<EhailingPage> createState() => _EhailingPageState();
}

enum _Role { none, passenger, driver }

class _EhailingPageState extends State<EhailingPage> {
  _Role _role = _Role.none;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: _role == _Role.none
          ? _RoleSelector(onSelect: (r) => setState(() => _role = r))
          : Column(
              children: [
                _RoleSwitchBar(role: _role, onSwitch: () => setState(() => _role = _Role.none)),
                Expanded(child: _role == _Role.passenger ? const _PassengerView() : const _DriverView()),
              ],
            ),
    );
  }
}

class _RoleSwitchBar extends StatelessWidget {
  final _Role role;
  final VoidCallback onSwitch;
  const _RoleSwitchBar({required this.role, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: Colors.white,
      child: Row(
        children: [
          Icon(role == _Role.passenger ? Icons.person_rounded : Icons.badge_rounded, color: const Color(0xFF667EEA), size: 18),
          const SizedBox(width: 8),
          Text(role == _Role.passenger ? l10n.passengerMode : l10n.driverMode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const Spacer(),
          TextButton.icon(onPressed: onSwitch, icon: const Icon(Icons.swap_horiz_rounded, size: 16), label: Text(l10n.switchLabel, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

// ========================================================================
// ROLE SELECTOR
// ========================================================================
class _RoleSelector extends StatelessWidget {
  final void Function(_Role) onSelect;
  const _RoleSelector({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.local_taxi_rounded, size: 56, color: Color(0xFF667EEA)),
        const SizedBox(height: 16),
        Text(l10n.ehailingSafetyTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(l10n.ehailingRoleSubtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 28),
        _roleCard(
          icon: Icons.person_rounded,
          title: l10n.imAPassenger,
          desc: l10n.passengerDesc,
          color: const Color(0xFF007BFF),
          onTap: () => onSelect(_Role.passenger),
        ),
        const SizedBox(height: 16),
        _roleCard(
          icon: Icons.badge_rounded,
          title: l10n.imADriver,
          desc: l10n.driverDesc,
          color: const Color(0xFFDC3545),
          onTap: () => onSelect(_Role.driver),
        ),
      ],
    );
  }

  Widget _roleCard({required IconData icon, required String title, required String desc, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4))],
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

// ========================================================================
// PASSENGER VIEW
// ========================================================================
class _PassengerView extends StatefulWidget {
  const _PassengerView();

  @override
  State<_PassengerView> createState() => _PassengerViewState();
}

class _PassengerViewState extends State<_PassengerView> {
  EhailService? _service;
  bool _tripShared = false;
  bool _sharing = false;
  bool _ending = false;
  int? _tripId;

  final TextEditingController _driverName = TextEditingController();
  final TextEditingController _vehicleReg = TextEditingController();
  final TextEditingController _vehicleModel = TextEditingController();
  final TextEditingController _vehicleColor = TextEditingController();
  final TextEditingController _pickup = TextEditingController();
  final TextEditingController _destination = TextEditingController();
  final TextEditingController _verifyPin = TextEditingController();

  // Real Protected contacts (those who have the app), loaded after the trip is shared.
  List<String> _protectedContacts = [];

  late final _PanicFlow _panic = _PanicFlow(onUpdate: () => setState(() {}));

  @override
  void dispose() {
    _panic.dispose();
    super.dispose();
  }

  Future<void> _loadProtectedContacts() async {
    try {
      final list = await ContactsService.listContacts();
      final names = <String>[];
      for (final item in list) {
        final dynamic c = item;
        final dynamic hasApp = c is Map ? c['has_app'] : c.hasApp;
        if (hasApp == true) {
          final dynamic name = c is Map ? c['name'] : c.name;
          names.add(name.toString());
        }
      }
      if (!mounted) return;
      setState(() => _protectedContacts = names);
    } catch (_) {
      // Contacts are best-effort here — the trip is already shared.
    }
  }

  void _triggerPanic() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.triggerPanicTitle),
        content: Text(
          _tripShared ? l10n.panicConfirmWithTrip : l10n.panicConfirmNoTrip,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545)),
            onPressed: () {
              Navigator.pop(context);
              _panic.trigger(role: 'passenger', trip: _tripId);
            },
            child: Text(l10n.triggerAlert, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareTrip() async {
    if (_service == null || _driverName.text.trim().isEmpty || _vehicleReg.text.trim().isEmpty) return;
    setState(() => _sharing = true);
    try {
      final result = await EhailingService.createTrip(
        service: _service!.value,
        driverName: _driverName.text.trim(),
        vehicleReg: _vehicleReg.text.trim(),
        vehicleModel: _vehicleModel.text.trim(),
        vehicleColor: _vehicleColor.text.trim(),
        pickupLocation: _pickup.text.trim(),
        destinationLocation: _destination.text.trim(),
        verificationPin: _verifyPin.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _tripId = result['id'] as int?;
        _tripShared = true;
        _sharing = false;
      });
      _loadProtectedContacts();
    } on EhailingException catch (e) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _endTrip() async {
    if (_tripId == null) return;
    setState(() => _ending = true);
    try {
      await EhailingService.endTrip(_tripId!);
    } on EhailingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (!mounted) return;
    setState(() {
      _ending = false;
      _tripShared = false;
      _tripId = null;
      _service = null;
      _driverName.clear();
      _vehicleReg.clear();
      _vehicleModel.clear();
      _vehicleColor.clear();
      _pickup.clear();
      _destination.clear();
      _verifyPin.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_panic.isActive) {
      return buildPanicActiveScreen(
        l10n: l10n,
        flow: _panic,
        contextLabel: _tripShared ? l10n.contextTripAttached(_service?.name ?? 'Trip') : l10n.contextNoTrip,
      );
    }

    final Widget content = _tripShared
        ? _buildTripActive()
        : _service == null
            ? _buildServicePicker()
            : _buildTripForm();

    return Stack(
      children: [
        content,
        Positioned(
          right: 16,
          bottom: 16,
          child: GestureDetector(
            onTap: _triggerPanic,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDC3545),
                boxShadow: [BoxShadow(color: const Color(0xFFDC3545).withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicePicker() {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF007BFF), Color(0xFF0056B3)]), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.pickRideApp, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(l10n.chooseYourRide, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3),
          itemBuilder: (context, i) {
            final s = _services[i];
            return GestureDetector(
              onTap: () => setState(() => _service = s),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))]),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(s.icon, color: s.color, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTripForm() {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _service!.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(_service!.icon, color: _service!.color, size: 22),
            ),
            const SizedBox(width: 10),
            Text(l10n.tripDetailsTitle(_service!.name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(onPressed: () => setState(() => _service = null), icon: const Icon(Icons.close_rounded)),
          ],
        ),
        const SizedBox(height: 16),
        _field(l10n.driverNameLabel, Icons.person_rounded, _driverName, l10n.driverNameHint),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _field(l10n.vehicleRegLabel, Icons.pin_rounded, _vehicleReg, l10n.vehicleRegHint)),
            const SizedBox(width: 10),
            Expanded(child: _field(l10n.vehicleColorLabel, Icons.palette_rounded, _vehicleColor, l10n.vehicleColorHint)),
          ],
        ),
        const SizedBox(height: 12),
        _field(l10n.vehicleModelLabel, Icons.directions_car_rounded, _vehicleModel, l10n.vehicleModelHint),
        const SizedBox(height: 12),
        LocationField(controller: _pickup, label: l10n.pickupLocationLabel, hint: l10n.pickupLocationHint),
        const SizedBox(height: 12),
        LocationField(controller: _destination, label: l10n.destinationLabel, hint: l10n.destinationHint, icon: Icons.flag_rounded),
        const SizedBox(height: 12),
        _field(l10n.verificationPinLabel, Icons.pin_rounded, _verifyPin, l10n.verificationPinHint),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFF856404), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.pinWarning,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF856404), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.info_rounded, color: Color(0xFF007BFF), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.tripSharedInfo, style: const TextStyle(fontSize: 12, color: Color(0xFF1A3D7C)))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745), padding: const EdgeInsets.symmetric(vertical: 15)),
            onPressed: _sharing ? null : _shareTrip,
            icon: _sharing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share_location_rounded, color: Colors.white),
            label: Text(_sharing ? l10n.sharingEllipsis : l10n.shareTripButton, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildTripActive() {
    final l10n = AppLocalizations.of(context)!;
    final now = TimeOfDay.now().format(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF28A745), Color(0xFF20C997)]), borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 10),
              Text(l10n.tripSharedSuccess, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l10n.startedAt(now), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _summaryCard(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF28A745), size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.sentTo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              if (_protectedContacts.isEmpty)
                Text(l10n.noProtectedContacts, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
              ..._protectedContacts.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF28A745), size: 16),
                        const SizedBox(width: 8),
                        Text(c, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC3545), padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: Color(0xFFDC3545))),
            onPressed: _ending ? null : _endTrip,
            icon: _ending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC3545)))
                : const Icon(Icons.stop_circle_rounded),
            label: Text(_ending ? l10n.endingEllipsis : l10n.endTrip),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_service!.icon, color: _service!.color, size: 20),
              const SizedBox(width: 8),
              Text(_service!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const Divider(height: 20),
          _detailRow(Icons.person_rounded, l10n.rowDriver, _driverName.text),
          _detailRow(Icons.pin_rounded, l10n.rowRegistration, _vehicleReg.text),
          if (_vehicleModel.text.isNotEmpty) _detailRow(Icons.directions_car_rounded, l10n.rowVehicle, '${_vehicleModel.text} (${_vehicleColor.text})'),
          if (_pickup.text.isNotEmpty) _detailRow(Icons.location_on_rounded, l10n.rowPickup, _pickup.text),
          if (_destination.text.isNotEmpty) _detailRow(Icons.flag_rounded, l10n.rowDestination, _destination.text),
          if (_verifyPin.text.isNotEmpty) _detailRow(Icons.pin_rounded, l10n.rowPinConfirmed, _verifyPin.text),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 10),
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _field(String label, IconData icon, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(prefixIcon: Icon(icon, size: 19), hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ],
    );
  }
}

// ========================================================================
// DRIVER VIEW
// ========================================================================
class DriverPost {
  final int id;
  final String driverName;
  final String message;
  final DateTime createdAt;
  const DriverPost({required this.id, required this.driverName, required this.message, required this.createdAt});

  factory DriverPost.fromJson(Map<String, dynamic> json) => DriverPost(
        id: json['id'] as int,
        driverName: json['driver_name']?.toString() ?? 'Unknown',
        message: json['message']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class DriverCommunity {
  final int id;
  final String name;
  final String area;
  final int memberCount;
  const DriverCommunity({required this.id, required this.name, required this.area, required this.memberCount});

  factory DriverCommunity.fromJson(Map<String, dynamic> json) => DriverCommunity(
        id: json['id'] as int,
        name: json['name']?.toString() ?? '',
        area: json['area']?.toString() ?? '',
        memberCount: json['member_count'] as int? ?? 0,
      );
}

class _DriverView extends StatefulWidget {
  const _DriverView();

  @override
  State<_DriverView> createState() => _DriverViewState();
}

class _DriverViewState extends State<_DriverView> {
  bool _loadingCommunities = true;
  String? _communitiesError;
  List<DriverCommunity> _availableCommunities = [];
  DriverCommunity? _community;

  bool _loadingPosts = false;
  List<DriverPost> _posts = [];
  final TextEditingController _postComposer = TextEditingController();
  bool _posting = false;

  // ---- Passenger logging (driver side) ----
  final TextEditingController _passengerName = TextEditingController();
  final TextEditingController _passengerPhone = TextEditingController();
  final TextEditingController _pickupLoc = TextEditingController();
  final TextEditingController _destinationLoc = TextEditingController();
  final TextEditingController _logNotes = TextEditingController();
  int _passengerCount = 1;
  File? _passengerPhoto;
  bool _passengerLogged = false;
  bool _loggingPassenger = false;
  bool _droppingOff = false;
  bool _autoCheckIn = false;
  String _tripPin = '';
  int? _passengerLogId;
  DateTime? _loggedAt;
  Timer? _tripClock;
  Duration _elapsed = Duration.zero;

  late final _PanicFlow _panic = _PanicFlow(onUpdate: () => setState(() {}));

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    setState(() {
      _loadingCommunities = true;
      _communitiesError = null;
    });
    try {
      final list = await EhailingService.listCommunities();
      if (!mounted) return;
      setState(() {
        _availableCommunities = list.map((e) => DriverCommunity.fromJson(e as Map<String, dynamic>)).toList();
        _loadingCommunities = false;
      });
    } on EhailingException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCommunities = false;
        _communitiesError = e.message;
      });
    }
  }

  Future<void> _joinCommunity(DriverCommunity c) async {
    try {
      await EhailingService.joinCommunity(c.id);
      if (!mounted) return;
      setState(() => _community = c);
      _loadPosts();
    } on EhailingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _leaveCommunity() async {
    if (_community == null) return;
    try {
      await EhailingService.leaveCommunity(_community!.id);
    } on EhailingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    setState(() {
      _community = null;
      _posts = [];
    });
  }

  Future<void> _loadPosts() async {
    if (_community == null) return;
    setState(() => _loadingPosts = true);
    try {
      final list = await EhailingService.listCommunityPosts(_community!.id);
      if (!mounted) return;
      setState(() {
        _posts = list.map((e) => DriverPost.fromJson(e as Map<String, dynamic>)).toList();
        _loadingPosts = false;
      });
    } on EhailingException catch (e) {
      if (!mounted) return;
      setState(() => _loadingPosts = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _submitPost() async {
    if (_community == null || _postComposer.text.trim().isEmpty) return;
    setState(() => _posting = true);
    try {
      await EhailingService.createCommunityPost(_community!.id, _postComposer.text.trim());
      _postComposer.clear();
      await _loadPosts();
    } on EhailingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (!mounted) return;
    setState(() => _posting = false);
  }

  void _createCommunity() {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.createCommunityTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.communityNameLabel, prefixIcon: const Icon(Icons.groups_rounded, size: 19), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: areaCtrl,
              decoration: InputDecoration(labelText: l10n.communityAreaLabel, prefixIcon: const Icon(Icons.map_rounded, size: 19), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                final result = await EhailingService.createCommunity(
                  name: nameCtrl.text.trim(),
                  area: areaCtrl.text.trim().isEmpty ? 'Your area' : areaCtrl.text.trim(),
                );
                final newId = result['id'] as int;
                await EhailingService.joinCommunity(newId);
                if (!mounted) return;
                setState(() {
                  _community = DriverCommunity(
                    id: newId,
                    name: result['name']?.toString() ?? nameCtrl.text.trim(),
                    area: result['area']?.toString() ?? areaCtrl.text.trim(),
                    memberCount: 1,
                  );
                  _posts = [];
                });
              } on EhailingException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
            child: Text(l10n.createAndJoin, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPassengerPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
      if (picked != null) setState(() => _passengerPhoto = File(picked.path));
    } catch (_) {
      // Camera unavailable (e.g. emulator) — safe to ignore, photo stays optional.
    }
  }

  Future<void> _logPassenger() async {
    if (_passengerName.text.trim().isEmpty) return;
    setState(() => _loggingPassenger = true);
    try {
      final result = await EhailingService.createPassengerLog(
        passengerName: _passengerName.text.trim(),
        passengerPhone: _passengerPhone.text.trim(),
        pickupLocation: _pickupLoc.text.trim(),
        destinationLocation: _destinationLoc.text.trim(),
        passengerCount: _passengerCount,
        notes: _logNotes.text.trim(),
        photo: _passengerPhoto,
        autoCheckIn: _autoCheckIn,
      );
      if (!mounted) return;
      setState(() {
        _passengerLogId = result['id'] as int?;
        _tripPin = result['trip_pin']?.toString() ?? '';
        _loggedAt = DateTime.tryParse(result['logged_at']?.toString() ?? '') ?? DateTime.now();
        _passengerLogged = true;
        _elapsed = Duration.zero;
        _loggingPassenger = false;
      });
      _tripClock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_loggedAt != null && mounted) setState(() => _elapsed = DateTime.now().difference(_loggedAt!));
      });
    } on EhailingException catch (e) {
      if (!mounted) return;
      setState(() => _loggingPassenger = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _endPassengerLog() async {
    if (_passengerLogId == null) return;
    setState(() => _droppingOff = true);
    try {
      await EhailingService.dropOffPassengerLog(_passengerLogId!);
    } on EhailingException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    _tripClock?.cancel();
    if (!mounted) return;
    setState(() {
      _droppingOff = false;
      _passengerLogged = false;
      _passengerName.clear();
      _passengerPhone.clear();
      _pickupLoc.clear();
      _destinationLoc.clear();
      _logNotes.clear();
      _passengerPhoto = null;
      _passengerCount = 1;
      _tripPin = '';
      _passengerLogId = null;
      _loggedAt = null;
    });
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _triggerPanic() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.triggerPanicTitle),
        content: Text(l10n.panicConfirmNoTrip),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545)),
            onPressed: () {
              Navigator.pop(context);
              _panic.trigger(role: 'driver', community: _community?.id, passengerLog: _passengerLogId);
            },
            child: Text(l10n.triggerAlert, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _panic.dispose();
    _tripClock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_panic.isActive) {
      return buildPanicActiveScreen(
        l10n: l10n,
        flow: _panic,
        contextLabel: _community != null
            ? l10n.contextCommunityNotified(_community!.name)
            : (_passengerLogged ? l10n.contextPassengerAttached : l10n.contextNoCommunity),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPanicButton(),
        const SizedBox(height: 20),
        _buildPassengerLog(),
        const SizedBox(height: 20),
        _buildCommunitySection(),
      ],
    );
  }

  Widget _buildCommunitySection() {
    final l10n = AppLocalizations.of(context)!;
    if (_loadingCommunities) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()));
    }

    if (_communitiesError != null && _community == null) {
      return Column(
        children: [
          Text(_communitiesError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _loadCommunities, child: Text(l10n.retry)),
        ],
      );
    }

    if (_community == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: Color(0xFF667EEA), size: 20),
              const SizedBox(width: 8),
              Text(l10n.driverCommunity, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.joinCommunityPrompt, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          if (_availableCommunities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.noCommunitiesYet, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            ),
          ..._availableCommunities.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF667EEA).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.groups_rounded, color: Color(0xFF667EEA), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(l10n.membersCount(c.area, c.memberCount), style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                          ],
                        ),
                      ),
                      TextButton(onPressed: () => _joinCommunity(c), child: Text(l10n.join)),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF667EEA), padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: Color(0xFF667EEA))),
              onPressed: _createCommunity,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(l10n.createNewCommunity),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF5A67D8)]), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_community!.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(l10n.membersCount(_community!.area, _community!.memberCount), style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  ],
                ),
              ),
              TextButton(onPressed: _leaveCommunity, style: TextButton.styleFrom(foregroundColor: Colors.white), child: Text(l10n.leave)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(l10n.communityUpdatesInfo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _postComposer,
                decoration: InputDecoration(
                  hintText: l10n.shareUpdateHint,
                  hintStyle: const TextStyle(fontSize: 12.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _posting ? null : _submitPost,
              icon: _posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Color(0xFF667EEA)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingPosts)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
        else if (_posts.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(l10n.noPostsYet, style: const TextStyle(fontSize: 12.5, color: Colors.grey)))
        else
          ..._posts.map((p) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _driverPostCard(p))),
      ],
    );
  }

  Widget _buildPanicButton() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFDC3545), Color(0xFFC82333)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: const Color(0xFFDC3545).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(l10n.inDanger, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(l10n.alertsAdminInstantly, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _triggerPanic,
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.warning_rounded, color: Color(0xFFDC3545), size: 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerLog() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)]),
      child: _passengerLogged ? _buildPassengerLogActive() : _buildPassengerLogForm(),
    );
  }

  Widget _buildPassengerLogForm() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF667EEA), size: 20),
            const SizedBox(width: 8),
            Text(l10n.logThisPassenger, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.logPassengerSubtitle, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)),
        const SizedBox(height: 14),
        _logField(l10n.passengerNameLabel, Icons.person_rounded, _passengerName, l10n.passengerNameHint),
        const SizedBox(height: 10),
        _logField(l10n.passengerPhoneLabel, Icons.phone_rounded, _passengerPhone, l10n.passengerPhoneHint),
        const SizedBox(height: 10),
        LocationField(controller: _pickupLoc, label: l10n.pickupPointLabel, hint: l10n.pickupPointHint),
        const SizedBox(height: 10),
        LocationField(controller: _destinationLoc, label: l10n.destinationLabel, hint: l10n.dropoffHint, icon: Icons.flag_rounded),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.groups_2_rounded, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(l10n.passengersInVehicle, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(onPressed: _passengerCount > 1 ? () => setState(() => _passengerCount--) : null, icon: const Icon(Icons.remove_circle_outline_rounded), visualDensity: VisualDensity.compact),
            Text('$_passengerCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            IconButton(onPressed: _passengerCount < 6 ? () => setState(() => _passengerCount++) : null, icon: const Icon(Icons.add_circle_outline_rounded), visualDensity: VisualDensity.compact),
          ],
        ),
        const SizedBox(height: 10),
        _logField(l10n.notesOptionalLabel, Icons.edit_note_rounded, _logNotes, l10n.notesHint),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickPassengerPhoto,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.withValues(alpha: 0.3))),
            child: Row(
              children: [
                if (_passengerPhoto != null)
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_passengerPhoto!, width: 40, height: 40, fit: BoxFit.cover))
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF667EEA).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF667EEA), size: 20),
                  ),
                const SizedBox(width: 10),
                Expanded(child: Text(_passengerPhoto != null ? l10n.photoCaptured : l10n.addPassengerPhoto, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.pin_rounded, color: Color(0xFF007BFF), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.pinGeneratedInfo, style: const TextStyle(fontSize: 11.5, color: Color(0xFF1A3D7C), height: 1.3))),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _loggingPassenger ? null : _logPassenger,
            icon: _loggingPassenger
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_user_rounded, color: Colors.white, size: 18),
            label: Text(_loggingPassenger ? l10n.loggingEllipsis : l10n.logPassengerButton, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildPassengerLogActive() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFF28A745)),
            const SizedBox(width: 8),
            Text(l10n.passengerLogged, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF28A745).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.timer_rounded, size: 13, color: Color(0xFF28A745)),
                  const SizedBox(width: 4),
                  Text(_formatElapsed(_elapsed), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF28A745))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF5A67D8)]), borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Text(l10n.verificationPinCaps, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(_tripPin, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
              const SizedBox(height: 4),
              Text(l10n.tellPassengerPin, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_passengerPhoto != null)
              ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(_passengerPhoto!, width: 48, height: 48, fit: BoxFit.cover))
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFF667EEA).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_rounded, color: Color(0xFF667EEA)),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_passengerName.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (_passengerPhone.text.isNotEmpty) Text(_passengerPhone.text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(l10n.passengersCountLabel(_passengerCount), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        if (_pickupLoc.text.isNotEmpty || _destinationLoc.text.isNotEmpty) ...[
          const Divider(height: 24),
          if (_pickupLoc.text.isNotEmpty) _logDetailRow(Icons.location_on_rounded, l10n.rowPickup, _pickupLoc.text),
          if (_destinationLoc.text.isNotEmpty) _logDetailRow(Icons.flag_rounded, l10n.rowDestination, _destinationLoc.text),
        ],
        if (_logNotes.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          _logDetailRow(Icons.edit_note_rounded, l10n.rowNotes, _logNotes.text),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              const Icon(Icons.groups_rounded, color: Color(0xFF28A745), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.attachedToRecord, style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534)))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _autoCheckIn,
          onChanged: (v) => setState(() => _autoCheckIn = v),
          activeThumbColor: const Color(0xFF667EEA),
          title: Text(l10n.autoSafetyCheckIn, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          subtitle: Text(l10n.autoCheckInSub, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF28A745), padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Color(0xFF28A745))),
            onPressed: _droppingOff ? null : _endPassengerLog,
            icon: _droppingOff
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF28A745)))
                : const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(_droppingOff ? l10n.savingEllipsis : l10n.markDroppedOff),
          ),
        ),
      ],
    );
  }

  Widget _logDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(width: 78, child: Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _logField(String label, IconData icon, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18),
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _driverPostCard(DriverPost p) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF667EEA),
            child: Text(p.driverName.isNotEmpty ? p.driverName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(p.driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(_timeAgo(l10n, p.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(p.message, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}