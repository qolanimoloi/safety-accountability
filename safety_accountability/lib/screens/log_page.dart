import '../widgets/location_field.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/activity_log_service.dart';

const List<Map<String, String>> _activityTypes = [
  {'value': 'date', 'label': 'Date'},
  {'value': 'travel', 'label': 'Travel'},
  {'value': 'meeting_new_person', 'label': 'Meeting New Person'},
  {'value': 'job_interview', 'label': 'Job Interview'},
  {'value': 'property_viewing', 'label': 'Property Viewing'},
  {'value': 'ride_share', 'label': 'Ride Share'},
  {'value': 'online_purchase_meetup', 'label': 'Online Purchase Meetup'},
  {'value': 'other', 'label': 'Other'},
];

Color _statusColor(String status, bool isOverdue) {
  if (isOverdue) return const Color(0xFFDC3545);
  switch (status) {
    case 'upcoming':
      return const Color(0xFF007BFF);
    case 'active':
      return const Color(0xFF28A745);
    case 'completed':
      return const Color(0xFF6C757D);
    case 'cancelled':
      return const Color(0xFF6C757D);
    default:
      return const Color(0xFF6C757D);
  }
}

// Mirrors NO_RETURN_TIME_GRACE_HOURS on the backend (activity_log/models.py).
const int _noReturnGraceHours = 6;

/// Server times arrive with a timezone; always show and compare them in the
/// phone's own local time.
DateTime? _parseDt(dynamic v) => DateTime.tryParse(v?.toString() ?? '')?.toLocal();

bool _isClosed(Map<String, dynamic> a) {
  final s = a['status'];
  return s == 'completed' || s == 'cancelled';
}

/// The moment the person should have been back by.
DateTime? _deadline(Map<String, dynamic> a) {
  final expected = _parseDt(a['expected_return_at']);
  if (expected != null) return expected;
  final scheduled = _parseDt(a['scheduled_at']);
  return scheduled?.add(const Duration(hours: _noReturnGraceHours));
}

/// Worked out against the phone's clock so the screen reacts the moment the
/// time passes, without waiting for the next refresh from the server.
bool _isOverdueNow(Map<String, dynamic> a) {
  if (_isClosed(a)) return false;
  final expected = _parseDt(a['expected_return_at']);
  if (expected == null) return a['is_overdue'] == true;
  return a['is_overdue'] == true || DateTime.now().isAfter(expected);
}

bool _canEscalateNow(Map<String, dynamic> a) {
  if (a['is_escalated'] == true || _isClosed(a)) return false;
  if (a['can_escalate'] == true) return true;
  final d = _deadline(a);
  return d != null && DateTime.now().isAfter(d);
}

String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> with WidgetsBindingObserver {
  bool _showMine = true;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _sharedWithMe = [];
  bool _showCreateForm = false;

  Timer? _ticker;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
    // Re-check the clock every few seconds so "Overdue" and the
    // "Send to admin" button appear the moment the time passes.
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
    // Pull fresh data quietly so a contact sees changes (a new activity,
    // the person marking themselves safe, the admin's progress) without
    // having to pull-to-refresh.
    _poller = Timer.periodic(const Duration(seconds: 15), (_) => _refreshSilently());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSilently();
  }

  Future<void> _refreshSilently() async {
    if (!mounted || _loading) return;
    try {
      final results = await Future.wait([
        ActivityLogService.listMine(),
        ActivityLogService.listSharedWithMe(),
      ]);
      if (!mounted) return;
      setState(() {
        _mine = results[0];
        _sharedWithMe = results[1];
      });
    } catch (_) {
      // Quiet on purpose: a failed background refresh shouldn't interrupt anyone.
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ActivityLogService.listMine(),
        ActivityLogService.listSharedWithMe(),
      ]);
      if (!mounted) return;
      setState(() {
        _mine = results[0];
        _sharedWithMe = results[1];
        _loading = false;
      });
    } on ActivityLogException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _deleteMine(int id) async {
    final previous = _mine;
    setState(() => _mine = _mine.where((a) => a['id'] != id).toList());
    try {
      await ActivityLogService.delete(id);
    } on ActivityLogException catch (e) {
      if (!mounted) return;
      setState(() => _mine = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _markSafe(int id) async {
    try {
      final updated = await ActivityLogService.markSafe(id);
      if (!mounted) return;
      setState(() => _mine = _mine.map((a) => a['id'] == id ? updated : a).toList());
    } on ActivityLogException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// A contact sends an overdue activity to the admin team.
  Future<void> _escalate(Map<String, dynamic> activity) async {
    final name = activity['logger_name']?.toString() ?? 'this person';
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _EscalateDialog(personName: name),
    );
    if (note == null) return; // cancelled

    try {
      final updated = await ActivityLogService.escalate(activity['id'] as int, note: note);
      if (!mounted) return;
      setState(() => _sharedWithMe = _sharedWithMe.map((a) => a['id'] == activity['id'] ? updated : a).toList());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent to the admin team. They will take it from here.')),
      );
    } on ActivityLogException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      _refreshSilently();
    }
  }

  Future<void> _submitNew({
    required String activityType,
    required DateTime scheduledAt,
    DateTime? expectedReturnAt,
    required String location,
    String personName = '',
    File? personPhoto,
    String carReg = '',
    File? carPhoto,
    String notes = '',
  }) async {
    try {
      final created = await ActivityLogService.create(
        activityType: activityType,
        scheduledAt: scheduledAt,
        expectedReturnAt: expectedReturnAt,
        location: location,
        personName: personName,
        personPhoto: personPhoto,
        carReg: carReg,
        carPhoto: carPhoto,
        notes: notes,
      );
      if (!mounted) return;
      setState(() {
        _mine = [created, ..._mine];
        _showCreateForm = false;
      });
    } on ActivityLogException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildInfoBanner(),
            const SizedBox(height: 16),
            _buildToggle(),
            if (_showMine && _showCreateForm) ...[
              const SizedBox(height: 16),
              _CreateActivityForm(onCancel: () => setState(() => _showCreateForm = false), onSubmit: _submitNew),
            ],
            const SizedBox(height: 20),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              _buildErrorState()
            else
              _showMine ? _buildMineList() : _buildSharedList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.report_gmailerrorred_rounded, color: Color(0xFFDC3545), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Activity Log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Track your activities for safety', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          if (_showMine) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => setState(() => _showCreateForm = !_showCreateForm),
                icon: Icon(_showCreateForm ? Icons.close_rounded : Icons.add_rounded, color: Colors.white, size: 20),
                label: Text(_showCreateForm ? 'Cancel' : 'Log New Activity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _toggleButton('My Activities', _showMine, () => setState(() => _showMine = true))),
          Expanded(child: _toggleButton('My Contacts', !_showMine, () => setState(() => _showMine = false))),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? const Color(0xFF007BFF) : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : const Color(0xFF495057), fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _buildInfoBanner() {
    final text = _showMine
        ? 'Always log activities when meeting someone new or going to unfamiliar places. This stays private between you and your emergency contacts. The admin team only sees it if one of your contacts reports that you did not return by your expected time.'
        : "Activities logged by people who've added you as their emergency contact. The admin team can't see these. If someone doesn't return by their expected time and you can't reach them, tap Send to admin so the team can act and involve the authorities.";
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(10), border: const Border(left: BorderSide(color: Color(0xFFFFC107), width: 4))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFF856404), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF856404), height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(28),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_error ?? 'Could not load activities.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadAll, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.event_note_rounded, size: 46, color: Colors.grey),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMineList() {
    if (_mine.isEmpty) return _buildEmptyState('No activities logged yet', 'Start by logging your first activity above');
    return Column(
      children: [
        const Align(alignment: Alignment.centerLeft, child: Text('Your Logged Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 14),
        ..._mine.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ActivityCard(
                activity: a,
                onView: () => _showActivityDetails(a),
                onDelete: () => _deleteMine(a['id'] as int),
                onMarkSafe: (a['status'] != 'completed' && a['status'] != 'cancelled') ? () => _markSafe(a['id'] as int) : null,
              ),
            )),
      ],
    );
  }

  Widget _buildSharedList() {
    if (_sharedWithMe.isEmpty) {
      return _buildEmptyState('Nothing shared yet', "Activities logged by people who've added you as their emergency contact will show up here");
    }
    return Column(
      children: [
        const Align(alignment: Alignment.centerLeft, child: Text("Your Contacts' Activities", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 14),
        ..._sharedWithMe.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SharedActivityCard(
                activity: a,
                onView: () => _showActivityDetails(a),
                onEscalate: () => _escalate(a),
              ),
            )),
      ],
    );
  }

  void _showActivityDetails(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _ActivityDetailsSheet(activity: a),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback? onMarkSafe;

  const _ActivityCard({required this.activity, required this.onView, required this.onDelete, this.onMarkSafe});

  @override
  Widget build(BuildContext context) {
    final scheduled = _parseDt(activity['scheduled_at']);
    final expectedReturn = _parseDt(activity['expected_return_at']);
    final isOverdue = _isOverdueNow(activity);
    final status = activity['status'] as String? ?? 'upcoming';
    final personName = (activity['person_name'] as String?) ?? '';
    final carReg = (activity['car_reg'] as String?) ?? '';
    final isEscalated = activity['is_escalated'] == true;
    final adminLabel = activity['admin_status_display']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _statusColor(status, isOverdue), borderRadius: BorderRadius.circular(20)),
                child: Text(activity['activity_type_display']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Row(
                children: [
                  IconButton(onPressed: onView, icon: const Icon(Icons.visibility_outlined, size: 19), constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero),
                  const SizedBox(width: 4),
                  IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFDC3545)), constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (scheduled != null) _detailRow(Icons.calendar_today_rounded, _fmtDate(scheduled)),
          if (scheduled != null) _detailRow(Icons.access_time_rounded, '${_fmtTime(scheduled)}${expectedReturn != null ? ' - ${_fmtTime(expectedReturn)}' : ''}'),
          _detailRow(Icons.location_on_rounded, activity['location']?.toString() ?? ''),
          if (personName.isNotEmpty) _detailRow(Icons.person_rounded, personName),
          if (carReg.isNotEmpty) _detailRow(Icons.directions_car_rounded, carReg),
          if (isEscalated)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.campaign_rounded, size: 18, color: Color(0xFFDC3545)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'One of your contacts sent this to the admin team${adminLabel.isEmpty ? '' : ' · $adminLabel'}. If you are safe, tap "I\'m Safe".',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFB02A37), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isOverdue ? 'Overdue' : (activity['status_display']?.toString() ?? ''), style: TextStyle(color: _statusColor(status, isOverdue), fontWeight: FontWeight.bold, fontSize: 12)),
              if (onMarkSafe != null)
                TextButton.icon(
                  onPressed: onMarkSafe,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: const Color(0xFF28A745)),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text("I'm Safe", style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [Icon(icon, size: 16, color: Colors.grey[600]), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(fontSize: 13)))]),
    );
  }
}

class _SharedActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final VoidCallback onView;
  final VoidCallback onEscalate;

  const _SharedActivityCard({required this.activity, required this.onView, required this.onEscalate});

  Future<void> _call(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = _parseDt(activity['scheduled_at']);
    final isOverdue = _isOverdueNow(activity);
    final status = activity['status'] as String? ?? 'upcoming';
    final loggerName = activity['logger_name']?.toString() ?? 'Someone';
    final loggerPhone = activity['logger_phone']?.toString();
    final isEscalated = activity['is_escalated'] == true;
    final canEscalate = _canEscalateNow(activity);
    final expectedBack = _parseDt(activity['expected_return_at']);
    final adminLabel = activity['admin_status_display']?.toString() ?? '';
    final closed = status == 'completed' || status == 'cancelled';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isOverdue ? Border.all(color: const Color(0xFFDC3545), width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Row(children: [const Icon(Icons.person_rounded, size: 18, color: Color(0xFF667EEA)), const SizedBox(width: 6), Expanded(child: Text(loggerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)))])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _statusColor(status, isOverdue), borderRadius: BorderRadius.circular(16)),
                child: Text(isOverdue ? 'OVERDUE' : (activity['status_display']?.toString() ?? ''), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(activity['activity_type_display']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (scheduled != null) Text('${_fmtDate(scheduled)} · ${_fmtTime(scheduled)}', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(activity['location']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: onView,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), foregroundColor: const Color(0xFF667EEA)),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Details', style: TextStyle(fontSize: 12)),
              ),
              if (loggerPhone != null && loggerPhone.isNotEmpty) ...[
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: () => _call(loggerPhone),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), foregroundColor: const Color(0xFF28A745)),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: const Text('Call', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
          if (isEscalated)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFE6F7EC), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF28A745)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sent to the admin team${adminLabel.isEmpty ? '' : ' · $adminLabel'}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E7E34), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else if (canEscalate)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC3545),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onEscalate,
                  icon: const Icon(Icons.campaign_rounded, color: Colors.white, size: 18),
                  label: const Text('Send to admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            )
          else if (!closed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                expectedBack != null
                    ? "Expected back by ${_fmtTime(expectedBack)}. If they haven't returned by then, the Send to admin button will appear here."
                    : "If they don't return in time, you can send this to the admin team.",
                style: const TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}

class _EscalateDialog extends StatefulWidget {
  final String personName;
  const _EscalateDialog({required this.personName});

  @override
  State<_EscalateDialog> createState() => _EscalateDialogState();
}

class _EscalateDialogState extends State<_EscalateDialog> {
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Send ${widget.personName} to admin?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Only do this if you have tried to reach them and they haven't returned. The admin team will see their activity details, where they went, and your name and phone number, and may contact the authorities.",
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'What you have tried (optional), e.g. called 3 times, no answer',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545)),
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: const Text('Send to admin', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _ActivityDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityDetailsSheet({required this.activity});

  @override
  Widget build(BuildContext context) {
    final scheduled = _parseDt(activity['scheduled_at']);
    final expectedReturn = _parseDt(activity['expected_return_at']);
    final personName = (activity['person_name'] as String?) ?? '';
    final carReg = (activity['car_reg'] as String?) ?? '';
    final personPhoto = activity['person_photo'] as String?;
    final carPhoto = activity['car_photo'] as String?;
    final notes = (activity['notes'] as String?) ?? '';
    final loggerName = activity['logger_name'] as String?;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Activity Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          _section('Activity Information', [
            if (loggerName != null) _row('Logged By', loggerName),
            _row('Type', activity['activity_type_display']?.toString() ?? ''),
            if (scheduled != null) _row('Date', _fmtDate(scheduled)),
            if (scheduled != null) _row('Time', '${_fmtTime(scheduled)}${expectedReturn != null ? ' - ${_fmtTime(expectedReturn)}' : ''}'),
            _row('Location', activity['location']?.toString() ?? ''),
          ]),
          if (personName.isNotEmpty)
            _section('Person Details', [
              _row('Name', personName),
              if (personPhoto != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(personPhoto, height: 160, width: double.infinity, fit: BoxFit.cover))),
            ]),
          if (carReg.isNotEmpty)
            _section('Vehicle Details', [
              _row('Registration', carReg),
              if (carPhoto != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(carPhoto, height: 160, width: double.infinity, fit: BoxFit.cover))),
            ]),
          if (notes.isNotEmpty) _section('Additional Notes', [Text(notes, style: const TextStyle(fontSize: 14, height: 1.5))]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007BFF), fontSize: 15)), const SizedBox(height: 10), ...children]),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 90, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))), Expanded(child: Text(value, style: const TextStyle(fontSize: 13)))]),
    );
  }
}

class _CreateActivityForm extends StatefulWidget {
  final VoidCallback onCancel;
  final Future<void> Function({
    required String activityType,
    required DateTime scheduledAt,
    DateTime? expectedReturnAt,
    required String location,
    String personName,
    File? personPhoto,
    String carReg,
    File? carPhoto,
    String notes,
  }) onSubmit;

  const _CreateActivityForm({required this.onCancel, required this.onSubmit});

  @override
  State<_CreateActivityForm> createState() => _CreateActivityFormState();
}

class _CreateActivityFormState extends State<_CreateActivityForm> {
  String _type = _activityTypes.first['value']!;
  DateTime? _date;
  TimeOfDay? _time;
  TimeOfDay? _returnTime;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _personNameController = TextEditingController();
  final TextEditingController _carRegController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  File? _personPhoto;
  File? _carPhoto;
  bool _submitting = false;

  Future<void> _pickImage(bool isPerson) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        if (isPerson) {
          _personPhoto = File(picked.path);
        } else {
          _carPhoto = File(picked.path);
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        if (isStart) {
          _time = picked;
        } else {
          _returnTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_date == null || _time == null || _locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in date, start time and location.')));
      return;
    }

    final scheduledAt = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    final expectedReturnAt = _returnTime == null ? null : DateTime(_date!.year, _date!.month, _date!.day, _returnTime!.hour, _returnTime!.minute);

    setState(() => _submitting = true);
    await widget.onSubmit(
      activityType: _type,
      scheduledAt: scheduledAt,
      expectedReturnAt: expectedReturnAt,
      location: _locationController.text.trim(),
      personName: _personNameController.text.trim(),
      personPhoto: _personPhoto,
      carReg: _carRegController.text.trim(),
      carPhoto: _carPhoto,
      notes: _notesController.text.trim(),
    );
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Log New Activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), GestureDetector(onTap: widget.onCancel, child: const Icon(Icons.close_rounded))]),
          const SizedBox(height: 18),
          const Text('Activity Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            items: _activityTypes.map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!))).toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _pickerField('Date *', Icons.calendar_today_rounded, _date == null ? '' : _fmtDate(_date!), _pickDate)),
              const SizedBox(width: 10),
              Expanded(child: _pickerField('Start Time *', Icons.access_time_rounded, _time == null ? '' : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}', () => _pickTime(true))),
            ],
          ),
          const SizedBox(height: 14),
          _pickerField('Expected Return', Icons.access_time_rounded, _returnTime == null ? '' : '${_returnTime!.hour.toString().padLeft(2, '0')}:${_returnTime!.minute.toString().padLeft(2, '0')}', () => _pickTime(false)),
          const SizedBox(height: 14),
                   LocationField(
            controller: _locationController,
            label: 'Meeting Location *',
            hint: 'Search address or place',
          ),
          const SizedBox(height: 14),
          _textField('Person You\'re Meeting', Icons.person_rounded, _personNameController, 'Full name of person'),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: _photoPicker('Person\'s Photo', _personPhoto, () => _pickImage(true))), const SizedBox(width: 10), Expanded(child: _photoPicker('Vehicle Photo', _carPhoto, () => _pickImage(false)))]),
          const SizedBox(height: 14),
          _textField('Vehicle Registration', Icons.directions_car_rounded, _carRegController, 'e.g., CA 123-456'),
          const SizedBox(height: 14),
          const Text('Additional Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(controller: _notesController, maxLines: 3, decoration: InputDecoration(hintText: 'Any additional information that might be helpful...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: _submitting ? null : widget.onCancel, child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  label: const Text('Log Activity', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pickerField(String label, IconData icon, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0), width: 2), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [Icon(icon, size: 18, color: Colors.grey[600]), const SizedBox(width: 10), Text(value.isEmpty ? 'Select' : value, style: TextStyle(color: value.isEmpty ? Colors.grey : Colors.black87, fontSize: 14))]),
          ),
        ),
      ],
    );
  }

  Widget _textField(String label, IconData icon, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(controller: controller, decoration: InputDecoration(prefixIcon: Icon(icon, size: 20), hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
      ],
    );
  }

  Widget _photoPicker(String label, File? file, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), border: Border.all(color: const Color(0xFFDEE2E6), width: 2), borderRadius: BorderRadius.circular(10)),
            child: file == null
                ? const Column(children: [Icon(Icons.camera_alt_rounded, color: Color(0xFF495057)), SizedBox(height: 6), Text('Upload Photo', style: TextStyle(fontSize: 12, color: Color(0xFF495057)))])
                : Column(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(file, height: 60, width: double.infinity, fit: BoxFit.cover)),
                      const SizedBox(height: 6),
                      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_rounded, color: Color(0xFF28A745), size: 14), SizedBox(width: 4), Text('Uploaded', style: TextStyle(fontSize: 11, color: Color(0xFF28A745)))]),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}