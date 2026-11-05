import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/circle_monitor.dart';
import '../services/circles_service.dart';
import '../widgets/place_picker.dart';
import '../widgets/user_avatar.dart';

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _daysLabel(List days) {
  final d = days.map((e) => (e as num).toInt()).toList()..sort();
  if (d.length == 7) return 'Every day';
  if (d.isEmpty) return 'No days';
  return d.map((i) => _dayNames[i]).join(', ');
}

String _when(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

String _describe(Map<String, dynamic> p) {
  final kind = p['kind']?.toString();
  final payload = Map<String, dynamic>.from(p['payload'] as Map);
  if (kind == 'curfew') {
    if (payload['enabled'] != true) return 'Turn the curfew off';
    return 'Curfew ${payload['start']} to ${payload['end']} (${_daysLabel(payload['days'] as List)})';
  }
  if (kind == 'zone_add') return 'Add restricted place "${payload['name']}" (${payload['radius_m']} m)';
  return 'Remove restricted place "${payload['name'] ?? ''}"';
}

class CircleDetailPage extends StatefulWidget {
  final int circleId;
  const CircleDetailPage({super.key, required this.circleId});

  @override
  State<CircleDetailPage> createState() => _CircleDetailPageState();
}

class _CircleDetailPageState extends State<CircleDetailPage> {
  Map<String, dynamic>? _c;
  List<Map<String, dynamic>> _proposals = [];
  List<Map<String, dynamic>> _alerts = [];
  String? _error;
  bool _busy = false;
  Timer? _timer;

  int get _id => widget.circleId;
  bool get _active => _c?['my_status'] == 'active';
  bool get _invited => _c?['my_status'] == 'invited';
  bool get _canSetRules => _c?['can_set_rules'] == true;
  bool get _voteMode => _c?['rules_mode'] == 'vote';
  bool get _iAmLeader => _c?['my_role'] == 'leader';

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final c = await CirclesService.get(_id);
      List<Map<String, dynamic>> props = [];
      List<Map<String, dynamic>> alerts = [];
      if (c['my_status'] == 'active') {
        props = await CirclesService.proposals(_id).catchError((_) => <Map<String, dynamic>>[]);
        alerts = await CirclesService.alerts(_id).catchError((_) => <Map<String, dynamic>>[]);
      }
      if (!mounted) return;
      setState(() {
        _c = c;
        _proposals = props;
        _alerts = alerts;
        _error = null;
      });
    } on CircleException catch (e) {
      if (!mounted) return;
      if (_c != null && quiet) return;
      setState(() => _error = e.message);
    }
  }

  /// Runs an action, shows any error, reloads, and tells the phone monitor the rules may have changed.
  Future<bool> _run(Future<void> Function() fn, {String? done}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      await fn();
      if (done != null) _toast(done);
      await _load();
      CircleMonitor.ensureRunning(forceRefresh: true);
      return true;
    } on CircleException catch (e) {
      _toast(e.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------- actions

  Future<void> _accept(bool accept) async {
    final ok = await _run(() => CirclesService.respond(_id, accept: accept), done: accept ? 'You joined the circle.' : 'Invitation declined.');
    if (ok && !accept && mounted) Navigator.pop(context);
  }

  Future<void> _setHome() async {
    final home = (_c!['members'] as List).cast<Map>().firstWhere((m) => m['is_me'] == true, orElse: () => {})['home'] as Map?;
    final pick = await showPlacePicker(
      context,
      title: 'Where is home?',
      confirmLabel: 'Use this as my home',
      initial: home == null ? null : LatLng((home['latitude'] as num).toDouble(), (home['longitude'] as num).toDouble()),
      initialRadius: (home?['radius_m'] as num?)?.toInt() ?? 150,
      maxRadius: 500,
      hint: 'Stand at home and tap the location button, or tap the map where home is.',
    );
    if (pick == null) return;
    await _run(() => CirclesService.setHome(_id, pick.latitude, pick.longitude, pick.radiusM), done: 'Home saved.');
  }

  Future<void> _editCurfew() async {
    final cf = Map<String, dynamic>.from(_c!['curfew'] as Map);
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _CurfewDialog(curfew: cf, vote: _voteMode));
    if (result == null) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await CirclesService.setCurfew(_id, result);
      _toast(r['applied'] == true ? 'Curfew saved. Everyone was told.' : 'Sent to the group. It starts when most people agree.');
      await _load();
      CircleMonitor.ensureRunning(forceRefresh: true);
    } on CircleException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addZone() async {
    final pick = await showPlacePicker(
      context,
      title: 'Restricted place',
      confirmLabel: 'Next',
      initialRadius: 300,
      minRadius: 50,
      maxRadius: 5000,
      color: const Color(0xFFDC3545),
      hint: 'Tap the map on a place members should stay away from, then size the area.',
    );
    if (pick == null || !mounted) return;
    final name = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
    if (name == null || name.trim().isEmpty) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await CirclesService.addZone(_id, name.trim(), pick.latitude, pick.longitude, pick.radiusM);
      _toast(r['applied'] == true ? 'Restricted place added. Everyone was told.' : 'Sent to the group. It starts when most people agree.');
      await _load();
      CircleMonitor.ensureRunning(forceRefresh: true);
    } on CircleException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeZone(Map z) async {
    final yes = await _confirm(
      _voteMode ? 'Suggest removing "${z['name']}"?' : 'Remove "${z['name']}"?',
      _voteMode ? 'The group will vote on it.' : 'The circle will no longer be alerted about this place.',
      _voteMode ? 'Suggest' : 'Remove',
    );
    if (yes != true || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await CirclesService.removeZone(_id, (z['id'] as num).toInt());
      _toast(r['applied'] == true ? 'Removed.' : 'Sent to the group to vote on.');
      await _load();
      CircleMonitor.ensureRunning(forceRefresh: true);
    } on CircleException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _vote(Map<String, dynamic> p, bool agree) =>
      _run(() => CirclesService.vote((p['id'] as num).toInt(), agree), done: agree ? 'You agreed.' : 'You said no.');

  Future<void> _invite() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _PersonSearchSheet(),
    );
    if (picked == null) return;
    await _run(() => CirclesService.invite(_id, (picked['id'] as num).toInt()), done: '${picked['name']} was invited. They must accept first.');
  }

  Future<bool?> _confirm(String title, String body, String action) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
  }

  Future<void> _leave() async {
    final yes = await _confirm('Leave this circle?', 'You will stop being checked against its rules and the circle will be told you left.', 'Leave');
    if (yes != true) return;
    final ok = await _run(() => CirclesService.leave(_id));
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final yes = await _confirm('Delete this circle?', 'This removes the circle, its rules and its alerts for everyone.', 'Delete');
    if (yes != true) return;
    final ok = await _run(() => CirclesService.delete(_id));
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _openMap(Map a) async {
    final lat = a['latitude'];
    final lng = a['longitude'];
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: Text(c?['name']?.toString() ?? 'Circle')),
      body: c == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ]),
                    )
                  : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(c),
                  const SizedBox(height: 12),
                  if (_invited) ..._invitedView(c) else ..._activeView(c),
                ],
              ),
            ),
    );
  }

  Widget _card({required Widget child, Color? border}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: border == null ? null : Border.all(color: border, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  Widget _title(String text, {IconData? icon, Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 19, color: const Color(0xFF667EEA)), const SizedBox(width: 8)],
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          if (trailing != null) trailing,
        ]),
      );

  Widget _header(Map<String, dynamic> c) {
    final kind = circleKindOf(c['kind'].toString());
    final vote = c['rules_mode'] == 'vote';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Icon(kind.icon, color: Colors.white, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${kind.label} circle', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 3),
            Text(
              vote ? 'Anyone can suggest a rule. It starts when most of the group agrees.' : 'Only leaders set the rules in this circle.',
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _curfewSummary(Map c) {
    final cf = c['curfew'] as Map;
    if (cf['enabled'] != true) return const Text('No curfew set.', style: TextStyle(color: Colors.grey));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${cf['start']} to ${cf['end']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      Text(_daysLabel(cf['days'] as List), style: const TextStyle(color: Colors.grey, fontSize: 12.5)),
      const SizedBox(height: 4),
      Text(
        'If you are not home ${(cf['grace_minutes'] as num).toInt() == 0 ? 'when it starts' : '${cf['grace_minutes']} minutes after it starts'}, the circle is told, with your last location.',
        style: const TextStyle(fontSize: 12.5, height: 1.35),
      ),
    ]);
  }

  Widget _zonesList(Map c, {required bool canRemove}) {
    final zones = (c['zones'] as List).cast<Map>();
    if (zones.isEmpty) return const Text('No restricted places.', style: TextStyle(color: Colors.grey));
    return Column(
      children: zones
          .map((z) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.block_rounded, color: Color(0xFFDC3545)),
                title: Text(z['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Within ${z['radius_m']} m', style: const TextStyle(fontSize: 12)),
                trailing: canRemove ? IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20), onPressed: () => _removeZone(z)) : null,
              ))
          .toList(),
    );
  }

  List<Widget> _invitedView(Map<String, dynamic> c) {
    return [
      _card(
        border: const Color(0xFF667EEA),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('You are invited', icon: Icons.mark_email_unread_rounded),
          const Text(
            'Read the rules below. They only apply to you if you accept, and you can leave at any time.',
            style: TextStyle(fontSize: 12.5, height: 1.35),
          ),
        ]),
      ),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_title('Curfew', icon: Icons.bedtime_rounded), _curfewSummary(c)])),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_title('Restricted places', icon: Icons.block_rounded), _zonesList(c, canRemove: false)])),
      _card(
        child: const Text(
          'How your location is used: your phone checks these rules itself. Your location is sent to the circle only when a rule is broken (past curfew and not home, or inside a restricted place). You choose where "home" is, and only you and the leaders can see it.',
          style: TextStyle(fontSize: 12.5, height: 1.4),
        ),
      ),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _busy ? null : () => _accept(false), child: const Text('Decline'))),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28A745), foregroundColor: Colors.white),
            onPressed: _busy ? null : () => _accept(true),
            child: const Text('Accept and join'),
          ),
        ),
      ]),
    ];
  }

  List<Widget> _activeView(Map<String, dynamic> c) {
    final members = (c['members'] as List).cast<Map>();
    final me = members.firstWhere((m) => m['is_me'] == true, orElse: () => {});
    final home = me['home'] as Map?;
    final cf = c['curfew'] as Map;
    final soleMember = members.where((m) => m['status'] == 'active').length == 1;
    final canDelete = (c['rules_mode'] == 'leader' && _iAmLeader) || (_voteMode && soleMember);
    return [
      _monitorCard(),
      // my home
      _card(
        border: cf['enabled'] == true && home == null ? const Color(0xFFF59E0B) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('My home', icon: Icons.home_rounded),
          Text(
            home == null
                ? (cf['enabled'] == true ? 'A curfew is on but you have not set your home. Set it so your phone can check.' : 'Not set. You choose where home is.')
                : 'Saved (${home['radius_m']} m area). Only you and the leaders can see it.',
            style: const TextStyle(fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton.icon(
              onPressed: _busy ? null : _setHome,
              icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
              label: Text(home == null ? 'Set my home' : 'Change'),
            ),
            if (home != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: _busy ? null : () => _run(() => CirclesService.clearHome(_id), done: 'Home removed.'), child: const Text('Remove')),
            ],
          ]),
        ]),
      ),
      // votes
      if (_proposals.any((p) => p['status'] == 'pending'))
        _card(
          border: const Color(0xFF667EEA),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title('Waiting for votes', icon: Icons.how_to_vote_rounded),
            ..._proposals.where((p) => p['status'] == 'pending').map(_proposalTile),
          ]),
        ),
      // curfew
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('Curfew', icon: Icons.bedtime_rounded,
              trailing: _canSetRules ? TextButton(onPressed: _busy ? null : _editCurfew, child: Text(_voteMode ? 'Suggest' : 'Edit')) : null),
          _curfewSummary(c),
          if (!_canSetRules) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Only leaders can change this.', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ]),
      ),
      // zones
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('Restricted places', icon: Icons.block_rounded,
              trailing: _canSetRules ? TextButton.icon(onPressed: _busy ? null : _addZone, icon: const Icon(Icons.add_rounded, size: 18), label: Text(_voteMode ? 'Suggest' : 'Add')) : null),
          const Text('If a member goes inside one of these, the circle is told straight away.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          _zonesList(c, canRemove: _canSetRules),
        ]),
      ),
      // alerts
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('Recent alerts', icon: Icons.notifications_active_rounded),
          if (_alerts.isEmpty)
            const Text('Nothing to report.', style: TextStyle(color: Colors.grey))
          else
            ..._alerts.take(10).map((a) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _openMap(a),
                  leading: Icon(a['kind'] == 'curfew' ? Icons.bedtime_rounded : Icons.block_rounded, color: const Color(0xFFDC3545)),
                  title: Text(
                    a['kind'] == 'curfew' ? '${a['name']} was not home after curfew' : '${a['name']} entered ${a['zone_name']}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${_when(a['created_at'].toString())} · tap to see location', style: const TextStyle(fontSize: 11.5)),
                )),
        ]),
      ),
      // members
      _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('People', icon: Icons.groups_rounded,
              trailing: (c['can_invite'] == true) ? TextButton.icon(onPressed: _busy ? null : _invite, icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('Invite')) : null),
          ...members.map(_memberTile),
        ]),
      ),
      if (canDelete)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC3545)),
          onPressed: _busy ? null : _delete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete circle'),
        )
      else
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC3545)),
          onPressed: _busy ? null : _leave,
          icon: const Icon(Icons.exit_to_app_rounded),
          label: const Text('Leave circle'),
        ),
      const SizedBox(height: 24),
    ];
  }

  Widget _proposalTile(Map<String, dynamic> p) {
    final mine = p['my_vote'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p['proposer']} suggests:', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(_describe(p), style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('${p['yes']} yes · ${p['no']} no · ${p['needed']} needed', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Row(children: [
          TextButton.icon(
            onPressed: _busy ? null : () => _vote(p, true),
            icon: Icon(Icons.thumb_up_alt_rounded, size: 17, color: mine == true ? const Color(0xFF28A745) : Colors.grey),
            label: Text('Agree', style: TextStyle(color: mine == true ? const Color(0xFF28A745) : null)),
          ),
          TextButton.icon(
            onPressed: _busy ? null : () => _vote(p, false),
            icon: Icon(Icons.thumb_down_alt_rounded, size: 17, color: mine == false ? const Color(0xFFDC3545) : Colors.grey),
            label: Text('No', style: TextStyle(color: mine == false ? const Color(0xFFDC3545) : null)),
          ),
        ]),
      ]),
    );
  }

  Widget _memberTile(Map m) {
    final invited = m['status'] == 'invited';
    final leaderControls = _c!['rules_mode'] == 'leader' && _iAmLeader && m['is_me'] != true;
    final home = m['home_set'] == true;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: m['name'].toString(), photoUrl: m['photo_url']?.toString(), radius: 19),
      title: Text('${m['name']}${m['is_me'] == true ? ' (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        invited ? 'Invited, has not accepted yet' : '${m['role'] == 'leader' ? 'Leader' : 'Member'} · ${home ? 'home set' : 'no home yet'}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: leaderControls
          ? PopupMenuButton<String>(
              onSelected: (v) {
                final uid = (m['user_id'] as num).toInt();
                if (v == 'promote') _run(() => CirclesService.promote(_id, uid), done: '${m['name']} is now a leader.');
                if (v == 'remove') _run(() => CirclesService.removeMember(_id, uid), done: '${m['name']} was removed.');
              },
              itemBuilder: (_) => [
                if (m['role'] != 'leader' && !invited) const PopupMenuItem(value: 'promote', child: Text('Make leader')),
                const PopupMenuItem(value: 'remove', child: Text('Remove from circle')),
              ],
            )
          : null,
    );
  }

  Widget _monitorCard() {
    return ValueListenableBuilder<CircleMonitorState>(
      valueListenable: CircleMonitor.state,
      builder: (context, s, _) {
        String text;
        Color color;
        IconData icon;
        bool fix = false;
        switch (s) {
          case CircleMonitorState.running:
            text = 'Your phone is checking the rules, even when the app is closed to the background.';
            color = const Color(0xFF28A745);
            icon = Icons.verified_user_rounded;
            break;
          case CircleMonitorState.foregroundOnly:
            text = 'Your phone only checks while the app is open. Set location to "Allow all the time" so the rules work in the background.';
            color = const Color(0xFFF59E0B);
            icon = Icons.warning_amber_rounded;
            fix = true;
            break;
          case CircleMonitorState.blocked:
            text = 'Location is off or not allowed, so your phone cannot check the rules. Turn it on.';
            color = const Color(0xFFDC3545);
            icon = Icons.location_off_rounded;
            fix = true;
            break;
          case CircleMonitorState.idle:
            text = 'Checks start once there is a curfew (with your home set) or a restricted place.';
            color = Colors.grey;
            icon = Icons.pause_circle_outline_rounded;
            break;
        }
        return _card(
          border: color,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title('Safety checks on this phone', icon: icon),
            Text(text, style: const TextStyle(fontSize: 12.5, height: 1.35)),
            const SizedBox(height: 4),
            const Text(
              'Checks pause if the phone is off, in battery saver that stops apps, or the app is force-closed.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.3),
            ),
            if (fix) TextButton(onPressed: () => Geolocator.openAppSettings(), child: const Text('Open app settings')),
          ]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- dialogs

class _CurfewDialog extends StatefulWidget {
  final Map<String, dynamic> curfew;
  final bool vote;
  const _CurfewDialog({required this.curfew, required this.vote});

  @override
  State<_CurfewDialog> createState() => _CurfewDialogState();
}

class _CurfewDialogState extends State<_CurfewDialog> {
  late bool _enabled;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<int> _days;
  late int _grace;

  static TimeOfDay _parse(String? s, TimeOfDay fallback) {
    if (s == null) return fallback;
    final p = s.split(':');
    final h = int.tryParse(p.first);
    final m = p.length > 1 ? int.tryParse(p[1]) : null;
    return (h == null || m == null) ? fallback : TimeOfDay(hour: h, minute: m);
  }

  @override
  void initState() {
    super.initState();
    final c = widget.curfew;
    _enabled = c['enabled'] == true || c['start'] == null;
    _start = _parse(c['start']?.toString(), const TimeOfDay(hour: 21, minute: 0));
    _end = _parse(c['end']?.toString(), const TimeOfDay(hour: 5, minute: 0));
    final days = (c['days'] as List?)?.map((e) => (e as num).toInt()).toSet() ?? {0, 1, 2, 3, 4, 5, 6};
    _days = days.isEmpty ? {0, 1, 2, 3, 4, 5, 6} : days;
    final g = (c['grace_minutes'] as num?)?.toInt() ?? 15;
    _grace = const [0, 5, 10, 15, 30, 60].contains(g) ? g : 15;
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final t = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (t == null) return;
    setState(() => start ? _start = t : _end = t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.vote ? 'Suggest a curfew' : 'Curfew'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _enabled, onChanged: (v) => setState(() => _enabled = v), title: const Text('Curfew on')),
          if (_enabled) ...[
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text('From ${_fmt(_start)}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text('Until ${_fmt(_end)}'))),
            ]),
            const SizedBox(height: 10),
            const Text('Days', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              spacing: 6,
              children: List.generate(
                7,
                (i) => FilterChip(
                  label: Text(_dayNames[i]),
                  selected: _days.contains(i),
                  onSelected: (v) => setState(() => v ? _days.add(i) : _days.remove(i)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              const Expanded(child: Text('Wait before alerting')),
              DropdownButton<int>(
                value: _grace,
                items: const [0, 5, 10, 15, 30, 60].map((m) => DropdownMenuItem(value: m, child: Text(m == 0 ? 'No wait' : '$m min'))).toList(),
                onChanged: (v) => setState(() => _grace = v ?? _grace),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('The curfew starts at the "From" time. Each person\'s phone checks whether they are at their own home.', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: (_enabled && _days.isEmpty)
              ? null
              : () => Navigator.pop(context, {
                    'enabled': _enabled,
                    if (_enabled) ...{'start': _fmt(_start), 'end': _fmt(_end), 'days': (_days.toList()..sort()), 'grace_minutes': _grace},
                  }),
          child: Text(widget.vote ? 'Send to group' : 'Save'),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this place'),
      content: TextField(controller: _c, maxLength: 60, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. The tavern, Old quarry')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _c.text), child: const Text('Add')),
      ],
    );
  }
}

class _PersonSearchSheet extends StatefulWidget {
  const _PersonSearchSheet();

  @override
  State<_PersonSearchSheet> createState() => _PersonSearchSheetState();
}

class _PersonSearchSheetState extends State<_PersonSearchSheet> {
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  int _gen = 0;

  Future<void> _search(String q) async {
    final gen = ++_gen;
    if (q.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await CirclesService.searchUsers(q.trim());
      if (!mounted || gen != _gen) return;
      setState(() {
        _results = r;
        _error = null;
        _loading = false;
      });
    } on CircleException catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const Expanded(child: Text('Invite someone', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('They must have the app. They will see the rules and choose whether to join.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          Expanded(
            child: ListView(
              children: _results
                  .map((u) => ListTile(
                        leading: UserAvatar(name: u['name'].toString(), photoUrl: u['photo_url']?.toString()),
                        title: Text(u['name'].toString()),
                        subtitle: Text(u['email']?.toString() ?? ''),
                        onTap: () => Navigator.pop(context, u),
                      ))
                  .toList(),
            ),
          ),
        ]),
      ),
    );
  }
}