import 'package:flutter/material.dart';

import '../app_nav.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/contacts_service.dart';
import '../services/profile_service.dart';
import 'last_seen_switch.dart';
import 'user_avatar.dart';

const List<String> _relationships = ['Parent', 'Sibling', 'Partner', 'Friend', 'Roommate', 'Colleague', 'Other'];

/// Opens a person's profile: picture, name, last seen, and the buttons
/// "Start chat" and "Add as emergency contact".
/// [name], [photoUrl] and [subtitle] are shown straight away; the rest is
/// loaded from the server a moment later.
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
    isScrollControlled: true,
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
  PublicProfile? _profile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await ProfileService.fetch(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loadingProfile = false;
      });
    } on ProfileException {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  String get _name => _profile?.name.isNotEmpty == true ? _profile!.name : widget.name;
  String? get _photo => _profile?.photoUrl ?? widget.photoUrl;

  void _viewPhoto() {
    final photo = _photo;
    if (photo == null || photo.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(dialogContext),
          child: InteractiveViewer(
            child: Image.network(
              photo,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(40),
                child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 50),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
        title: Text('How do you know $_name?'),
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
        SnackBar(content: Text('Request sent. $_name will be your emergency contact once they accept.')),
      );
    } on ContactsException catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _statusLine() {
    final p = _profile;
    if (p == null) {
      return Text(_loadingProfile ? 'Loading…' : '', style: const TextStyle(fontSize: 12.5, color: Colors.grey));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.online) ...[
          const Icon(Icons.circle, size: 9, color: Color(0xFF28A745)),
          const SizedBox(width: 5),
        ],
        Text(
          p.lastSeenLabel,
          style: TextStyle(fontSize: 12.5, color: p.online ? const Color(0xFF1E7E34) : Colors.grey, fontWeight: p.online ? FontWeight.w600 : FontWeight.normal),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final official = _profile?.isOfficial == true;
    final subtitle = widget.subtitle ?? (official ? 'Verified official account' : null);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 22, 24, 22 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _viewPhoto,
              child: UserAvatar(name: _name, photoUrl: _photo, radius: 44),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(_name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                if (official) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded, size: 20, color: Color(0xFF007BFF)),
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            ],
            const SizedBox(height: 6),
            _statusLine(),
            const SizedBox(height: 20),
            if (widget.isMe) ...[
              const Text('This is you.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              const LastSeenSwitch(),
            ] else ...[
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