import 'package:flutter/material.dart';

import '../app_nav.dart';
import '../screens/contacts_page.dart';
import '../services/chat_service.dart';
import '../services/contacts_service.dart';
import '../services/notification_service.dart';

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

IconData _iconFor(Map<String, dynamic> n) {
  switch (n['action']?.toString()) {
    case 'contact_request':
      return Icons.how_to_reg_rounded;
    case 'contact_response':
      return Icons.people_alt_rounded;
    case 'chat_message':
      return Icons.chat_bubble_rounded;
    case 'community_post':
      return Icons.forum_rounded;
    case 'open_emergency':
      return Icons.shield_rounded;
  }
  switch (n['type']?.toString()) {
    case 'alert':
      return Icons.shield_rounded;
    case 'message':
      return Icons.mail_rounded;
    case 'report':
      return Icons.notifications_rounded;
    case 'community':
      return Icons.forum_rounded;
    default:
      return Icons.info_outline_rounded;
  }
}

Color _colorFor(Map<String, dynamic> n) {
  switch (n['action']?.toString()) {
    case 'contact_request':
    case 'contact_response':
      return const Color(0xFF667EEA);
    case 'chat_message':
      return const Color(0xFF2563EB);
    case 'open_emergency':
      return const Color(0xFFDC2626);
  }
  switch (n['type']?.toString()) {
    case 'alert':
      return const Color(0xFFDC2626);
    case 'message':
      return const Color(0xFF2563EB);
    case 'report':
      return const Color(0xFF10B981);
    case 'community':
      return const Color(0xFF667EEA);
    default:
      return Colors.grey;
  }
}

String? _hintFor(Map<String, dynamic> n) {
  switch (n['action']?.toString()) {
    case 'contact_request':
      return 'Tap to accept or decline';
    case 'contact_response':
      return 'Tap to see your contacts';
    case 'chat_message':
      return 'Tap to open the chat';
    case 'community_post':
      return 'Tap to open Community';
    case 'open_emergency':
      return 'Tap to open Emergency';
  }
  return null;
}

String _relativeTime(String? iso) {
  final date = DateTime.tryParse(iso ?? '')?.toLocal();
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// The bell's list. Tapping a notification closes the sheet and returns it,
/// so the header can take you to what it is about.
class NotificationsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function() onMarkAllRead;

  const NotificationsSheet({super.key, required this.notifications, required this.onMarkAllRead});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  late List<Map<String, dynamic>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = widget.notifications;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
          ),
          const Text('Tap one to open it', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Expanded(
            child: _notifications.isEmpty
                ? const Center(child: Text('No notifications yet', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    controller: scrollController,
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final read = n['read'] == true;
                      final color = _colorFor(n);
                      final hint = _hintFor(n);
                      return ListTile(
                        onTap: () => Navigator.pop(context, n),
                        tileColor: read ? null : color.withValues(alpha: 0.07),
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(_iconFor(n), color: color, size: 20),
                        ),
                        title: Text(
                          n['message']?.toString() ?? '',
                          style: TextStyle(fontSize: 14, fontWeight: read ? FontWeight.normal : FontWeight.w600),
                        ),
                        subtitle: Text(
                          [_relativeTime(n['created_at']?.toString()), ?hint].join(' · '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: read ? null : CircleAvatar(radius: 5, backgroundColor: color),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _notifications.isEmpty
                    ? null
                    : () async {
                        setState(() => _notifications = _notifications.map((n) => {...n, 'read': true}).toList());
                        await widget.onMarkAllRead();
                      },
                child: const Text('Mark All as Read'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Takes the person to whatever a notification is about.
class NotificationRouter {
  static void _snack(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<void> _markRead(Map<String, dynamic> n) async {
    final id = n['id'];
    if (id is! int) return;
    try {
      await NotificationService.markOneRead(id);
    } catch (_) {
      // The next refresh reconciles it.
    }
  }

  static Future<void> open(BuildContext context, Map<String, dynamic> n, {VoidCallback? onChanged}) async {
    final action = n['action']?.toString() ?? '';
    final objectId = (n['object_id'] as num?)?.toInt();

    switch (action) {
      case 'contact_request':
        await _handleContactRequest(context, n, objectId);
        break;
      case 'contact_response':
        await _markRead(n);
        if (context.mounted) _openContactsPage(context);
        break;
      case 'chat_message':
        await _markRead(n);
        await _openChat(context, objectId);
        break;
      case 'community_post':
        await _markRead(n);
        AppNav.showTab(3);
        break;
      case 'open_emergency':
        await _markRead(n);
        AppNav.showTab(1);
        break;
      default:
        await _markRead(n);
    }
    onChanged?.call();
  }

  static Future<void> _handleContactRequest(BuildContext context, Map<String, dynamic> n, int? requestId) async {
    List<Map<String, dynamic>> requests;
    try {
      requests = await ContactsService.incomingRequests();
    } on ContactsException catch (e) {
      _snack(context, e.message);
      return;
    }

    final request = requests.where((r) => r['id'] == requestId).firstOrNull;
    if (request == null) {
      await _markRead(n);
      _snack(context, 'This request was already answered.');
      return;
    }
    if (!context.mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ContactRequestDialog(request: request),
    );
    if (result == null) return; // closed without answering: it stays unread

    await _markRead(n);
    final name = request['from_name']?.toString() ?? 'this person';
    _snack(context, result == 'accepted' ? 'You are now an emergency contact for $name.' : 'Request declined.');
  }

  static Future<void> _openChat(BuildContext context, int? conversationId) async {
    try {
      final list = await ChatService.listConversations();
      final conversation = list.where((c) => c['id'] == conversationId).firstOrNull;
      if (conversation != null) {
        AppNav.openChat(conversation);
        return;
      }
    } on ChatException catch (e) {
      _snack(context, e.message);
      return;
    }
    _snack(context, 'That conversation is no longer available.');
  }

  static void _openContactsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Emergency Contacts'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 1,
          ),
          body: const SafeArea(child: ContactsPage()),
        ),
      ),
    );
  }
}

/// The pop-up with the accept ✓ and decline ✕ buttons.
class _ContactRequestDialog extends StatefulWidget {
  final Map<String, dynamic> request;
  const _ContactRequestDialog({required this.request});

  @override
  State<_ContactRequestDialog> createState() => _ContactRequestDialogState();
}

class _ContactRequestDialogState extends State<_ContactRequestDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _respond(bool accept) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ContactsService.respondToRequest(widget.request['id'] as int, accept: accept);
      if (!mounted) return;
      Navigator.pop(context, accept ? 'accepted' : 'declined');
    } on ContactsException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Widget _answerButton(IconData icon, Color color, String label, bool accept) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: _busy ? null : () => _respond(accept),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: _busy ? Colors.grey : color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.request['from_name']?.toString() ?? 'Someone';
    final photo = widget.request['from_photo']?.toString();
    final relationship = widget.request['relationship']?.toString() ?? '';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF667EEA),
            backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
            child: (photo != null && photo.isNotEmpty)
                ? null
                : Text(_initialsOf(name), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            relationship.isEmpty ? 'wants to add you as an emergency contact' : 'listed you as: $relationship',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          const Text(
            'If you accept, you will get their emergency alerts and see the activities they log.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDC3545), fontSize: 12)),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _answerButton(Icons.close_rounded, const Color(0xFFDC3545), 'Decline', false),
              _answerButton(Icons.check_rounded, const Color(0xFF28A745), 'Accept', true),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }
}