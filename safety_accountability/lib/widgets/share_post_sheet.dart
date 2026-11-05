import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../services/community_service.dart';
import 'user_avatar.dart';

/// Called after a successful share. [sharesCount] is the post's new share
/// count; [reposted] is true when it was shared on the Community feed
/// (so the feed should be refreshed).
typedef ShareDone = void Function(int? sharesCount, bool reposted);

/// The Share button: choose where the post goes.
///  - Share on Community (a repost, like Facebook)
///  - Send in a chat (pick people or groups)
///  - Send to emergency contacts
Future<void> showSharePostSheet(
  BuildContext context, {
  required int postId,
  required ShareDone onDone,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Share this post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF007BFF), child: Icon(Icons.repeat_rounded, color: Colors.white)),
            title: const Text('Share on Community'),
            subtitle: const Text('Repost it on the feed so your community sees it'),
            onTap: () => Navigator.pop(sheetContext, 'community'),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF667EEA), child: Icon(Icons.chat_bubble_rounded, color: Colors.white)),
            title: const Text('Send in a chat'),
            subtitle: const Text('Choose people or groups to send it to'),
            onTap: () => Navigator.pop(sheetContext, 'chat'),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFDC2626), child: Icon(Icons.favorite_rounded, color: Colors.white)),
            title: const Text('Send to emergency contacts'),
            subtitle: const Text('Your accepted contacts who use the app'),
            onTap: () => Navigator.pop(sheetContext, 'contacts'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  switch (choice) {
    case 'community':
      await _shareToCommunity(context, messenger, postId, onDone);
      break;
    case 'chat':
      await _shareToChats(context, messenger, postId, onDone);
      break;
    case 'contacts':
      await _shareToContacts(context, messenger, postId, onDone);
      break;
  }
}

Future<void> _shareToCommunity(BuildContext context, ScaffoldMessengerState messenger, int postId, ShareDone onDone) async {
  final controller = TextEditingController();
  final comment = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Share on Community'),
      content: TextField(
        controller: controller,
        maxLines: 3,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Say something about this post (optional)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007BFF)),
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Share', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (comment == null) return;
  try {
    final result = await CommunityService.sharePost(postId, target: 'community', comment: comment);
    messenger.showSnackBar(const SnackBar(content: Text('Shared on the Community feed.')));
    onDone((result['shares_count'] as num?)?.toInt(), true);
  } on CommunityException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

Future<void> _shareToChats(BuildContext context, ScaffoldMessengerState messenger, int postId, ShareDone onDone) async {
  final ids = await showModalBottomSheet<List<int>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _ChatPickerSheet(),
  );
  if (ids == null || ids.isEmpty) return;
  try {
    final result = await CommunityService.sharePost(postId, target: 'chat', conversationIds: ids);
    final n = (result['sent_to'] as num?)?.toInt() ?? ids.length;
    messenger.showSnackBar(SnackBar(content: Text(n == 1 ? 'Sent to 1 chat.' : 'Sent to $n chats.')));
    onDone((result['shares_count'] as num?)?.toInt(), false);
  } on CommunityException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

Future<void> _shareToContacts(BuildContext context, ScaffoldMessengerState messenger, int postId, ShareDone onDone) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Send to emergency contacts?'),
      content: const Text('Your accepted emergency contacts who use the app will receive this post in their chat with you.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Send', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    final result = await CommunityService.sharePost(postId, target: 'contacts');
    final sent = (result['sent_to'] as num?)?.toInt() ?? 0;
    final without = ((result['without_app'] as List?) ?? const []).map((e) => e.toString()).toList();
    var text = sent == 0
        ? 'None of your emergency contacts use the app yet.'
        : (sent == 1 ? 'Sent to 1 emergency contact.' : 'Sent to $sent emergency contacts.');
    if (without.isNotEmpty) {
      text += ' ${without.join(', ')} ${without.length == 1 ? "does" : "do"} not have the app yet.';
    }
    messenger.showSnackBar(SnackBar(content: Text(text)));
    if (sent > 0) onDone((result['shares_count'] as num?)?.toInt(), false);
  } on CommunityException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Pick one or more chats. Pops with the list of chosen conversation ids.
class _ChatPickerSheet extends StatefulWidget {
  const _ChatPickerSheet();

  @override
  State<_ChatPickerSheet> createState() => _ChatPickerSheetState();
}

class _ChatPickerSheetState extends State<_ChatPickerSheet> {
  List<Map<String, dynamic>> _conversations = [];
  final Set<int> _selected = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ChatService.listConversations();
      if (!mounted) return;
      setState(() {
        _conversations = list;
        _loading = false;
      });
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Widget _avatar(Map<String, dynamic> c) {
    final url = c['avatar_url']?.toString();
    if (c['is_group'] == true) {
      if (url != null && url.isNotEmpty) {
        return ClipOval(
          child: Image.network(
            url,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const CircleAvatar(backgroundColor: Color(0xFF667EEA), child: Icon(Icons.groups_rounded, color: Colors.white)),
          ),
        );
      }
      return const CircleAvatar(backgroundColor: Color(0xFF667EEA), child: Icon(Icons.groups_rounded, color: Colors.white));
    }
    return UserAvatar(name: c['display_name']?.toString() ?? '', photoUrl: url, radius: 20, color: const Color(0xFFDC2626));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.7;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)));
    } else if (_conversations.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('You have no chats yet. Start one from Messages first.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    } else {
      body = ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, i) {
          final c = _conversations[i];
          final id = (c['id'] as num).toInt();
          return CheckboxListTile(
            value: _selected.contains(id),
            onChanged: (v) => setState(() {
              if (v == true) {
                _selected.add(id);
              } else {
                _selected.remove(id);
              }
            }),
            secondary: _avatar(c),
            title: Text(c['display_name']?.toString() ?? ''),
            subtitle: c['is_group'] == true ? Text('${c['member_count'] ?? 0} members') : null,
            controlAffinity: ListTileControlAffinity.trailing,
          );
        },
      );
    }
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
            child: Row(
              children: [
                const Expanded(child: Text('Send to…', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Expanded(child: body),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
                child: Text(
                  _selected.isEmpty ? 'Choose a chat' : 'Send (${_selected.length})',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}