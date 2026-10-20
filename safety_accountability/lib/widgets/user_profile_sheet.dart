import 'package:flutter/material.dart';

import '../app_nav.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/contacts_service.dart';

const List<String> _relationships = ['Parent', 'Sibling', 'Partner', 'Friend', 'Roommate', 'Colleague', 'Other'];

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// Opens a small profile with "Start chat" and "Add as emergency contact".
Future<void> showUserProfileSheet(
  BuildContext context, {
  required int userId,
  required String name,
  String? photoUrl,
  String? subtitle,
}) async {
  final me = await AuthService.getCachedUser();
  final isMe = me != null && me['id'] == userId;
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _UserProfileSheet(userId: userId, name: name, photoUrl: photoUrl, subtitle: subtitle, isMe: isMe),
  );
}

class _UserProfileSheet extends StatefulWidget {
  final int userId;
  final String name;
  final String? photoUrl;
  final String? subtitle;
  final bool isMe;

  const _UserProfileSheet({required this.userId, required this.name, this.photoUrl, this.subtitle, required this.isMe});

  @override
  State<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<_UserProfileSheet> {
  bool _busy = false;

  Future<void> _startChat() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final conversation = await ChatService.createConversation(memberIds: [widget.userId]);
      nav.pop();
      AppNav.openChat(conversation);
    } on ChatException catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addAsContact() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final relationship = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('How do you know ${widget.name}?'),
        children: _relationships
            .map((r) => SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, r), child: Text(r)))
            .toList(),
      ),
    );
    if (relationship == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ContactsService.addUserAsContact(widget.userId, relationship: relationship);
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Request sent. ${widget.name} will be your emergency contact once they accept.')),
      );
    } on ContactsException catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photoUrl;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: const Color(0xFF667EEA),
              backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
              child: (photo != null && photo.isNotEmpty)
                  ? null
                  : Text(_initialsOf(widget.name), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            Text(widget.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            ],
            const SizedBox(height: 20),
            if (widget.isMe)
              const Text('This is you.', style: TextStyle(color: Colors.grey))
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _busy ? null : _startChat,
                  icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                  label: const Text('Start chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _busy ? null : _addAsContact,
                  icon: const Icon(Icons.favorite_rounded, size: 18),
                  label: const Text('Add as emergency contact'),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}