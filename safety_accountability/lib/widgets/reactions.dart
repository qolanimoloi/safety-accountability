import 'package:flutter/material.dart';

import 'user_avatar.dart';
import 'user_profile_sheet.dart';

/// The six reactions shown first, like WhatsApp.
const List<String> kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

const List<String> _moreEmojis = [
  '😀', '😁', '😅', '🤣', '😊', '😍', '😘', '😎', '🤗', '🤔', '😐', '😴',
  '😭', '😡', '😱', '🥳', '🙄', '😬', '🤝', '👏', '🙌', '💪', '👌', '✌️',
  '🤞', '👎', '👀', '🔥', '💯', '🎉', '💔', '😇', '🤯', '🥺', '😢', '🆘',
  '🚨', '✅', '❌', '⚠️', '📍', '🏠', '🚗', '⏰', '📞', '🛡️', '💙', '🧡',
];

/// Turns the server's reactions list into a clean List of maps.
List<Map<String, dynamic>> parseReactions(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// The emoji I reacted with, or null.
String? myReaction(dynamic raw) {
  for (final r in parseReactions(raw)) {
    if (r['mine'] == true) return r['emoji']?.toString();
  }
  return null;
}

/// Opens the emoji picker. Returns the chosen emoji, or null if dismissed.
/// Choosing the emoji you already used removes it (the server toggles it).
Future<String?> showReactionPicker(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => _ReactionPicker(current: current),
  );
}

class _ReactionPicker extends StatefulWidget {
  final String? current;
  const _ReactionPicker({this.current});

  @override
  State<_ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<_ReactionPicker> {
  bool _more = false;

  Widget _emojiButton(String e, {double size = 30}) {
    final selected = widget.current == e;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.pop(context, e),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? const Color(0xFFE3EEFF) : Colors.transparent,
        ),
        child: Text(e, style: TextStyle(fontSize: size)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final e in kQuickReactions) _emojiButton(e),
                IconButton(
                  tooltip: 'More',
                  onPressed: () => setState(() => _more = !_more),
                  icon: Icon(_more ? Icons.keyboard_arrow_down_rounded : Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            if (_more) ...[
              const Divider(height: 18),
              SizedBox(
                height: 230,
                child: GridView.count(
                  crossAxisCount: 8,
                  children: [for (final e in _moreEmojis) _emojiButton(e, size: 24)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The little "👍 3  ❤️ 1" pills under a message or comment.
/// Tap a pill to add or remove that reaction. Press and hold to see who reacted.
class ReactionBar extends StatelessWidget {
  final dynamic reactions;
  final ValueChanged<String> onToggle;
  final EdgeInsetsGeometry padding;

  const ReactionBar({
    super.key,
    required this.reactions,
    required this.onToggle,
    this.padding = const EdgeInsets.only(top: 4),
  });

  @override
  Widget build(BuildContext context) {
    final list = parseReactions(reactions);
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        children: [
          for (final r in list)
            GestureDetector(
              onTap: () => onToggle(r['emoji'].toString()),
              onLongPress: () => showReactorsSheet(context, list),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r['mine'] == true ? const Color(0xFFE3EEFF) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: r['mine'] == true ? const Color(0xFF007BFF) : const Color(0xFFE0E3E8)),
                ),
                child: Text(
                  '${r['emoji']} ${r['count']}',
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lists everyone who reacted, grouped by emoji. Tap a person to open their profile.
Future<void> showReactorsSheet(BuildContext context, List<Map<String, dynamic>> reactions) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      expand: false,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text('Reactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          for (final r in reactions)
            for (final u in parseReactions(r['users']))
              ListTile(
                dense: true,
                leading: UserAvatar(name: u['name']?.toString() ?? '', photoUrl: u['photo_url']?.toString(), radius: 18),
                title: Text(u['name']?.toString() ?? 'Someone'),
                trailing: Text(r['emoji'].toString(), style: const TextStyle(fontSize: 22)),
                onTap: () {
                  final id = (u['id'] as num?)?.toInt();
                  if (id == null) return;
                  showUserProfileSheet(
                    context,
                    userId: id,
                    name: u['name']?.toString() ?? 'Someone',
                    photoUrl: u['photo_url']?.toString(),
                  );
                },
              ),
        ],
      ),
    ),
  );
}