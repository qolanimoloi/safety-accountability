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

  @override
  Widget build(BuildContext context) {
    if (!QuickSosService.supported) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SwitchListTile(
        value: _on,
        onChanged: _busy ? null : _toggle,
        activeThumbColor: const Color(0xFFDC2626),
        secondary: const Icon(Icons.warning_amber_rounded),
        title: const Text('Quick SOS (power button ×3)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: const Text(
          'Press the power button 3 times quickly. After a 5-second countdown (cancel anytime) your live location goes to admin.',
          style: TextStyle(fontSize: 11.5),
        ),
      ),
    );
  }
}