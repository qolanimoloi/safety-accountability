import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/quick_sos_service.dart';

class QuickSosTile extends StatefulWidget {
  const QuickSosTile({super.key});

  @override
  State<QuickSosTile> createState() => _QuickSosTileState();
}

class _QuickSosTileState extends State<QuickSosTile> {
  bool _on = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await QuickSosService.isEnabled();
    if (!mounted) return;
    setState(() => _on = on);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    if (value) {
      final res = await QuickSosService.enable();
      if (!mounted) return;
      setState(() {
        _on = res.ok;
        _busy = false;
      });
      if (res.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message!),
            duration: const Duration(seconds: 6),
            action: res.needsSettings
                ? SnackBarAction(label: 'Settings', onPressed: () => Geolocator.openAppSettings())
                : null,
          ),
        );
      }
    } else {
      await QuickSosService.disable();
      if (!mounted) return;
      setState(() {
        _on = false;
        _busy = false;
      });
    }
  }

  void _showTips() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Make Quick SOS reliable'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Press the power button twice quickly (within 3 seconds).\n\n'
            '2. Phones use power-button presses for their own shortcuts, and an app cannot switch those off. '
            'Turn them off in your phone settings:\n'
            '• Samsung: Settings > Advanced features > Side key, then turn off "Double press".\n'
            '• Huawei / Honor: Settings > Accessibility features, then turn off any shortcut that starts on a power-button press. The names differ by model.\n\n'
            '3. Let the app run in the background: Settings > Apps > this app > Battery > Unrestricted.\n\n'
            '4. Keep location on and stay signed in.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!QuickSosService.supported) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _on,
            onChanged: _busy ? null : _toggle,
            activeThumbColor: const Color(0xFFDC2626),
            secondary: const Icon(Icons.warning_amber_rounded),
            title: const Text('Quick SOS (double-press power button)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Double-press the power button quickly. After a 3-second countdown (cancel anytime) your live location goes to admin.',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextButton(
                onPressed: _showTips,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Phone not responding? Tap for tips', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}