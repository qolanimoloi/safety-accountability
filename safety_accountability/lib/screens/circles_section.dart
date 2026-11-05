import 'package:flutter/material.dart';

import '../services/circle_monitor.dart';
import '../services/circles_service.dart';
import 'circle_detail_page.dart';

/// The "Circles" block on the Emergency Contacts screen: invitations, your circles, and a New circle button.
class CirclesSection extends StatefulWidget {
  const CirclesSection({super.key});

  @override
  State<CirclesSection> createState() => CirclesSectionState();
}

class CirclesSectionState extends State<CirclesSection> {
  List<Map<String, dynamic>> _circles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final list = await CirclesService.list();
      if (!mounted) return;
      setState(() {
        _circles = list;
        _loading = false;
        _error = null;
      });
      CircleMonitor.ensureRunning();
    } on CircleException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CircleDetailPage(circleId: c['id'] as int)));
    if (!mounted) return;
    await reload();
    CircleMonitor.ensureRunning(forceRefresh: true);
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _NewCircleSheet(),
    );
    if (created == null || !mounted) return;
    await reload();
    if (!mounted) return;
    _open(created);
  }

  @override
  Widget build(BuildContext context) {
    final invites = _circles.where((c) => c['my_status'] == 'invited').toList();
    final mine = _circles.where((c) => c['my_status'] == 'active').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Circles', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
            TextButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('New circle'),
            ),
          ],
        ),
        const Text(
          'Family, friends, roommates and more. Agree on a curfew and places to avoid, and the circle is told if a rule is broken.',
          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.grey, fontSize: 12.5))
        else ...[
          ...invites.map((c) => _InviteCard(circle: c, onTap: () => _open(c))),
          ...mine.map((c) => _CircleCard(circle: c, onTap: () => _open(c))),
          if (invites.isEmpty && mine.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Text('You are not in any circle yet. Tap New circle to start one.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
        ],
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  final Map<String, dynamic> circle;
  final VoidCallback onTap;
  const _InviteCard({required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667EEA), width: 1.5),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.mark_email_unread_rounded, color: Color(0xFF667EEA)),
        title: Text('Invitation: ${circle['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text('${circle['kind_label']} circle. Tap to read the rules before you decide.', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  final Map<String, dynamic> circle;
  final VoidCallback onTap;
  const _CircleCard({required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final kind = circleKindOf(circle['kind']?.toString() ?? 'custom');
    final members = (circle['members'] as List).where((m) => (m as Map)['status'] == 'active').length;
    final zones = (circle['zones'] as List).length;
    final curfew = circle['curfew'] as Map;
    final pending = (circle['pending_proposals'] as num?)?.toInt() ?? 0;
    final needsHome = curfew['enabled'] == true && circle['my_home_set'] != true;
    final bits = <String>[
      '$members ${members == 1 ? 'person' : 'people'}',
      if (curfew['enabled'] == true) 'Curfew ${curfew['start']}-${curfew['end']}',
      if (zones > 0) '$zones restricted ${zones == 1 ? 'place' : 'places'}',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: const Color(0xFF667EEA), child: Icon(kind.icon, color: Colors.white, size: 20)),
        title: Text(circle['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${kind.label} · ${bits.join(' · ')}', style: const TextStyle(fontSize: 12)),
            if (needsHome) const Text('Set your home so the curfew can work.', style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
            if (pending > 0) Text('$pending ${pending == 1 ? 'vote' : 'votes'} waiting', style: const TextStyle(fontSize: 12, color: Color(0xFF667EEA), fontWeight: FontWeight.w600)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _NewCircleSheet extends StatefulWidget {
  const _NewCircleSheet();

  @override
  State<_NewCircleSheet> createState() => _NewCircleSheetState();
}

class _NewCircleSheetState extends State<_NewCircleSheet> {
  final _name = TextEditingController();
  String _kind = 'family';
  bool _leaderMode = false; // only used for Custom
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the circle a name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await CirclesService.create(name, _kind, rulesMode: _kind == 'custom' ? (_leaderMode ? 'leader' : 'vote') : null);
      if (mounted) Navigator.pop(context, c);
    } on CircleException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('New circle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 60,
              decoration: InputDecoration(labelText: 'Circle name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 4),
            const Text('Type of circle', style: TextStyle(fontWeight: FontWeight.w600)),
            ...kCircleKinds.map(
              (k) => RadioListTile<String>(
                value: k.key,
                groupValue: _kind,
                onChanged: (v) => setState(() => _kind = v ?? _kind),
                contentPadding: EdgeInsets.zero,
                secondary: Icon(k.icon, color: const Color(0xFF667EEA)),
                title: Text(k.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(k.blurb, style: const TextStyle(fontSize: 12)),
              ),
            ),
            if (_kind == 'custom')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _leaderMode,
                onChanged: (v) => setState(() => _leaderMode = v),
                title: const Text('Only leaders set the rules'),
                subtitle: Text(_leaderMode ? 'Leaders decide. Others follow.' : 'Anyone can suggest a rule and the group votes.', style: const TextStyle(fontSize: 12)),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(10)),
              child: Text(
                circleKindOf(_kind).leaderOnly || (_kind == 'custom' && _leaderMode)
                    ? 'People you invite must accept first, and they see every rule before they do.'
                    : 'People you invite must accept first. Rules only start once most of the group agrees.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF1A3D7C), height: 1.35),
              ),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5))),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _busy ? null : _save,
              child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create circle'),
            ),
          ],
        ),
      ),
    );
  }
}