import 'package:flutter/material.dart';

import '../services/profile_service.dart';

/// "Show my last seen" switch. Saved on the server, because it decides what
/// OTHER people see about you. Used in Privacy Settings and on your own profile.
class LastSeenSwitch extends StatefulWidget {
  const LastSeenSwitch({super.key});

  @override
  State<LastSeenSwitch> createState() => _LastSeenSwitchState();
}

class _LastSeenSwitchState extends State<LastSeenSwitch> {
  bool _value = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await ProfileService.getShowLastSeen();
      if (!mounted) return;
      setState(() {
        _value = v;
        _loaded = true;
      });
    } on ProfileException {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _change(bool v) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _value = v;
      _saving = true;
    });
    try {
      final saved = await ProfileService.setShowLastSeen(v);
      if (!mounted) return;
      setState(() {
        _value = saved;
        _saving = false;
      });
    } on ProfileException catch (e) {
      if (!mounted) return;
      setState(() {
        _value = !v;
        _saving = false;
      });
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: _value,
      onChanged: (_loaded && !_saving) ? _change : null,
      activeThumbColor: const Color(0xFF667EEA),
      contentPadding: EdgeInsets.zero,
      title: const Text('Show my last seen', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      subtitle: const Text(
        'When off, nobody can see when you were last active',
        style: TextStyle(fontSize: 11.5, color: Colors.grey),
      ),
    );
  }
}