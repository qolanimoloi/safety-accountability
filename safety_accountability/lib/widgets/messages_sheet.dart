import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/chat_service.dart';
import '../services/contacts_service.dart';
import '../services/profile_service.dart';
import 'location_field.dart' show CurrentLocation, PlaceSearchException;
import 'reactions.dart';
import 'stickers.dart';
import 'user_avatar.dart';
import 'user_profile_sheet.dart';
import 'video_viewer.dart';

const Color _red = Color(0xFFDC2626);
const Color _purple = Color(0xFF667EEA);
const int _maxFileBytes = 50 * 1024 * 1024;
const int _maxPending = 10;
const List<String> _relationships = ['Parent', 'Sibling', 'Partner', 'Friend', 'Roommate', 'Colleague', 'Other'];

final RegExp _locationRegex =
    RegExp(r'https://www\.google\.com/maps/search/\?api=1&query=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');

// ----------------------------------------------------------------- helpers

String _fmtTime(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _fmtDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString();
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _kindFromExt(String nameOrUrl) {
  final clean = nameOrUrl.toLowerCase().split('?').first;
  final ext = clean.contains('.') ? clean.split('.').last : '';
  if (const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) return 'image';
  if (const ['mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv'].contains(ext)) return 'video';
  if (const ['m4a', 'aac', 'mp3', 'wav', 'ogg', 'opus', 'amr'].contains(ext)) return 'audio';
  return ext.isEmpty ? '' : 'document';
}

/// What a received file is. Decided from the file name, so voice notes,
/// audio and documents work whatever the server calls them.
String _mediaKind(Map<String, dynamic> m) {
  final byExt = _kindFromExt(m['url']?.toString() ?? '');
  if (byExt.isNotEmpty) return byExt;
  final t = m['media_type']?.toString();
  return (t == 'video' || t == 'audio' || t == 'document') ? t! : 'image';
}

String _mediaName(Map<String, dynamic> m) {
  final url = m['url']?.toString() ?? '';
  final last = url.split('?').first.split('/').last;
  try {
    return Uri.decodeComponent(last);
  } catch (_) {
    return last;
  }
}

IconData _kindIcon(String kind) {
  switch (kind) {
    case 'video':
      return Icons.videocam_rounded;
    case 'audio':
      return Icons.mic_rounded;
    case 'image':
      return Icons.image_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

Future<void> _openExternal(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Widget _roundButton(IconData icon, VoidCallback onTap) {
  return Material(
    color: _red,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white, size: 22)),
    ),
  );
}

Future<String?> _pickRelationship(BuildContext context, String name) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text('How do you know $name?'),
      children: _relationships
          .map((r) => SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, r), child: Text(r)))
          .toList(),
    ),
  );
}

/// Sizes a sheet so it always sits ABOVE the keyboard, so you see what you type.
class _SheetFrame extends StatelessWidget {
  final Widget child;
  final double heightFactor;
  const _SheetFrame({required this.child}) : heightFactor = 0.9;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom;
    final available = media.size.height - media.padding.top - inset - 12;
    final height = math.max(math.min(media.size.height * heightFactor, available), 220.0);
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(height: height, child: child),
    );
  }
}

/// A chat's picture: the group icon, or the other person's profile photo
/// (their initials only when they have no photo).
class _ConversationAvatar extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final double radius;
  const _ConversationAvatar({required this.conversation, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation['is_group'] == true;
    final url = conversation['avatar_url']?.toString();
    if (!isGroup) {
      return UserAvatar(
        name: conversation['display_name']?.toString() ?? '',
        photoUrl: url,
        radius: radius,
        color: _red,
      );
    }
    final groupCircle = CircleAvatar(
      radius: radius,
      backgroundColor: _purple,
      child: Icon(Icons.groups_rounded, color: Colors.white, size: radius),
    );
    if (url == null || url.isEmpty) return groupCircle;
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => groupCircle,
      ),
    );
  }
}

// ===================================================================
// Messages: conversation list and chat
// ===================================================================

class MessagesSheet extends StatefulWidget {
  final List<Map<String, dynamic>> conversations;
  final ValueChanged<List<Map<String, dynamic>>> onConversationsChanged;
  final Map<String, dynamic>? initialConversation;

  const MessagesSheet({
    super.key,
    required this.conversations,
    required this.onConversationsChanged,
    this.initialConversation,
  });

  @override
  State<MessagesSheet> createState() => _MessagesSheetState();
}

class _MessagesSheetState extends State<MessagesSheet> {
  late List<Map<String, dynamic>> _conversations;
  Map<String, dynamic>? _selected;
  late bool _loadingList;
  String? _listError;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _conversations = widget.conversations;
    _selected = widget.initialConversation;
    _loadingList = widget.conversations.isEmpty;
    _loadConversations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_selected == null) _loadConversations();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await ChatService.listConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loadingList = false;
        _listError = null;
      });
      widget.onConversationsChanged(conversations);
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = e.message;
        _loadingList = false;
      });
    }
  }

  Future<void> _openNewChat() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _NewChatSheet(),
    );
    if (created == null || !mounted) return;
    setState(() {
      _conversations = [created, ..._conversations.where((c) => c['id'] != created['id'])];
      _selected = created;
    });
    widget.onConversationsChanged(_conversations);
  }

  void _backToList() {
    setState(() => _selected = null);
    _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: _selected == null
          ? _buildList()
          : _ChatThreadView(key: ValueKey(_selected!['id']), conversation: _selected!, onBack: _backToList),
    );
  }

  Widget _buildList() {
    Widget body;
    if (_loadingList) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_listError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_listError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              TextButton(onPressed: _loadConversations, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    } else if (_conversations.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.grey),
              const SizedBox(height: 10),
              const Text('No conversations yet', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Start a chat with someone or create a group', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _red),
                onPressed: _openNewChat,
                icon: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 18),
                label: const Text('New chat', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    } else {
      body = ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final c = _conversations[index];
          final unread = (c['unread_count'] as int?) ?? 0;
          return ListTile(
            onTap: () => setState(() => _selected = c),
            leading: _ConversationAvatar(conversation: c),
            title: Text(c['display_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c['last_message']?.toString() ?? 'No messages yet', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: unread > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(10)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  )
                : null,
          );
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(child: Text('Messages', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(onPressed: _openNewChat, icon: const Icon(Icons.add_comment_rounded), tooltip: 'New chat'),
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

// ===================================================================
// One conversation
// ===================================================================

class _Pending {
  final File file;
  final String name;
  final String kind;
  _Pending(this.file, this.name) : kind = _kindFromExt(name).isEmpty ? 'document' : _kindFromExt(name);
}

class _ChatThreadView extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onBack;

  const _ChatThreadView({super.key, required this.conversation, required this.onBack});

  @override
  State<_ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<_ChatThreadView> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();

  List<Map<String, dynamic>> _messages = [];
  final List<_Pending> _pending = [];
  bool _loading = true;
  bool _sending = false;
  String? _notice;
  Timer? _noticeTimer;
  Timer? _pollTimer;

  bool _recording = false;
  Duration _recElapsed = Duration.zero;
  Timer? _recTimer;

  // The other person in a one-to-one chat (for "last seen" under their name).
  PublicProfile? _other;
  Timer? _profileTimer;

  int get _conversationId => widget.conversation['id'] as int;
  bool get _isGroup => widget.conversation['is_group'] == true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    ChatService.markRead(_conversationId).catchError((_) {});
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollNew());
    _loadOther();
    _profileTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadOther());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _profileTimer?.cancel();
    _recTimer?.cancel();
    _noticeTimer?.cancel();
    _recorder.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    if (!mounted) return;
    setState(() => _notice = message);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  // --------------------------------------------------------------- loading

  Future<void> _loadMessages() async {
    try {
      final messages = await ChatService.listMessages(_conversationId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
    } on ChatException {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadOther() async {
    if (_isGroup) return;
    final id = (widget.conversation['other_member_id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final p = await ProfileService.fetch(id);
      if (!mounted) return;
      setState(() => _other = p);
    } on ProfileException {
      // Silent: the next refresh tries again.
    }
  }

  Future<void> _pollNew() async {
    if (_messages.isEmpty) {
      _loadMessages();
      return;
    }
    try {
      final lastId = _messages.last['id'] as int;
      final newer = await ChatService.listMessages(_conversationId, afterId: lastId);
      Map<int, List<Map<String, dynamic>>>? reactions;
      try {
        reactions = await ChatService.listReactions(_conversationId);
      } on ChatException {
        reactions = null;
      }
      if (!mounted) return;
      final reactionsChanged = reactions != null && _applyReactions(reactions);
      if (newer.isEmpty) {
        if (reactionsChanged) setState(() {});
        return;
      }
      setState(() {
        final known = _messages.map((m) => m['id']).toSet();
        _messages = [..._messages, ...newer.where((m) => !known.contains(m['id']))];
      });
      ChatService.markRead(_conversationId).catchError((_) {});
    } on ChatException {
      // Silent: the next poll tries again.
    }
  }

  /// Copies other people's new reactions onto the messages already on screen.
  /// Returns true if anything changed.
  bool _applyReactions(Map<int, List<Map<String, dynamic>>> fresh) {
    var changed = false;
    final windowStart = _messages.length > 200 ? _messages[_messages.length - 200]['id'] as int : 0;
    for (final m in _messages) {
      final id = m['id'] as int;
      if (id < windowStart) continue;
      final latest = fresh[id] ?? <Map<String, dynamic>>[];
      if (jsonEncode(m['reactions'] ?? const []) != jsonEncode(latest)) {
        m['reactions'] = latest;
        changed = true;
      }
    }
    return changed;
  }

  Future<void> _react(Map<String, dynamic> message, String emoji) async {
    try {
      final reactions = await ChatService.reactToMessage(message['id'] as int, emoji);
      if (!mounted) return;
      setState(() => message['reactions'] = reactions);
    } on ChatException catch (e) {
      _showNotice(e.message);
    }
  }

  Future<void> _pickReaction(Map<String, dynamic> message) async {
    final emoji = await showReactionPicker(context, current: myReaction(message['reactions']));
    if (emoji != null) _react(message, emoji);
  }

  void _openProfileOf(Map<String, dynamic> message) {
    final id = (message['sender_id'] as num?)?.toInt();
    if (id == null) return;
    showUserProfileSheet(
      context,
      userId: id,
      name: message['sender_name']?.toString() ?? '',
      photoUrl: message['sender_photo']?.toString(),
    );
  }

  /// Tap the chat's name: a person's profile (with last seen), or the group's info.
  Future<void> _openHeader() async {
    if (_isGroup) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _GroupInfoSheet(
          conversation: widget.conversation,
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
      );
      return;
    }
    final id = (widget.conversation['other_member_id'] as num?)?.toInt();
    if (id == null) return;
    showUserProfileSheet(
      context,
      userId: id,
      name: widget.conversation['display_name']?.toString() ?? '',
      photoUrl: widget.conversation['avatar_url']?.toString(),
    );
  }

  // --------------------------------------------------------------- sending

  Future<void> _send({String? textOverride, String sticker = '', List<File> extra = const []}) async {
    if (_sending) return;
    final text = (textOverride ?? _text.text).trim();
    final files = <File>[if (textOverride == null) ..._pending.map((p) => p.file), ...extra];
    if (text.isEmpty && files.isEmpty && sticker.isEmpty) return;

    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      final sent = await ChatService.sendMessage(conversationId: _conversationId, text: text, sticker: sticker, media: files);
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m['id'] == sent['id'])) _messages = [..._messages, sent];
        if (textOverride == null) {
          _text.clear();
          _pending.clear();
        }
      });
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    } on ChatException catch (e) {
      _showNotice(e.message);
    } catch (_) {
      _showNotice('Could not send. Check your connection and try again.');
    } finally {
      for (final f in extra) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
      if (mounted) setState(() => _sending = false);
    }
  }

  // ------------------------------------------------------------ attachments

  void _addFile(File file, String name) {
    if (_pending.length >= _maxPending) {
      _showNotice('You can attach up to $_maxPending files at once.');
      return;
    }
    try {
      if (file.lengthSync() > _maxFileBytes) {
        _showNotice('"$name" is over the 50MB limit.');
        return;
      }
    } catch (_) {
      _showNotice('Could not read "$name".');
      return;
    }
    setState(() => _pending.add(_Pending(file, name)));
  }

  Future<void> _openAttachMenu() async {
    FocusScope.of(context).unfocus();
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 18,
            runSpacing: 20,
            children: [
              _attachOption(sheetContext, 'camera', Icons.photo_camera_rounded, 'Camera', const Color(0xFFDC2626)),
              _attachOption(sheetContext, 'photos', Icons.photo_library_rounded, 'Photos', const Color(0xFF7E57C2)),
              _attachOption(sheetContext, 'video', Icons.videocam_rounded, 'Video', const Color(0xFFE91E63)),
              _attachOption(sheetContext, 'document', Icons.insert_drive_file_rounded, 'Document', const Color(0xFF2563EB)),
              _attachOption(sheetContext, 'audio', Icons.headphones_rounded, 'Audio', const Color(0xFFFF9800)),
              _attachOption(sheetContext, 'location', Icons.location_on_rounded, 'Location', const Color(0xFF28A745)),
              _attachOption(sheetContext, 'sticker', Icons.emoji_emotions_rounded, 'Sticker', const Color(0xFFF59E0B)),
              _attachOption(sheetContext, 'gif', Icons.gif_box_rounded, 'GIF', const Color(0xFF2563EB)),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'camera':
        await _pickCamera();
        break;
      case 'photos':
        await _pickPhotos();
        break;
      case 'video':
        await _pickVideo();
        break;
      case 'document':
        await _pickFiles(['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv']);
        break;
      case 'audio':
        await _pickFiles(['mp3', 'wav', 'm4a', 'aac']);
        break;
      case 'location':
        await _shareLocation();
        break;
      case 'sticker':
        await _sendSticker();
        break;
      case 'gif':
        // Picked as a file so the GIF keeps its animation.
        await _pickFiles(['gif']);
        break;
    }
  }

  Future<void> _sendSticker() async {
    final key = await showStickerPicker(context);
    if (key == null || !mounted) return;
    await _send(textOverride: '', sticker: key);
  }

  Widget _attachOption(BuildContext context, String value, IconData icon, String label, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pop(context, value),
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCamera() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
      if (x != null) _addFile(File(x.path), x.name);
    } catch (_) {
      _showNotice('Could not open the camera.');
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1920);
      for (final x in picked) {
        _addFile(File(x.path), x.name);
      }
    } catch (_) {
      _showNotice('Could not open your photos.');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (x != null) _addFile(File(x.path), x.name);
    } catch (_) {
      _showNotice('Could not open your videos.');
    }
  }

  Future<void> _pickFiles(List<String> extensions) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: extensions);
      if (files.isEmpty || !mounted) return;
      for (final f in files) {
        final path = f.path;
        if (path != null) _addFile(File(path), f.name);
      }
    } catch (_) {
      _showNotice('Could not open your files.');
    }
  }

  Future<void> _shareLocation() async {
    try {
      final pos = await CurrentLocation.get();
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Send your location?'),
          content: const Text('Everyone in this chat will see where you are right now.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final lat = pos.latitude.toStringAsFixed(6);
      final lng = pos.longitude.toStringAsFixed(6);
      await _send(textOverride: '📍 My location\nhttps://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } on PlaceSearchException catch (e) {
      _showNotice(e.message);
    } catch (_) {
      _showNotice('Could not get your location.');
    }
  }

  // ----------------------------------------------------------- voice notes

  Future<void> _startRecording() async {
    if (_sending || _recording) return;
    try {
      if (!await _recorder.hasPermission()) {
        _showNotice('Microphone permission is needed to record a voice note.');
        return;
      }
      FocusScope.of(context).unfocus();
      final path = '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recElapsed = Duration.zero;
      });
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recElapsed += const Duration(seconds: 1));
        if (_recElapsed.inMinutes >= 5) _sendRecording(); // keep notes to 5 minutes
      });
    } catch (_) {
      _showNotice('Could not start recording.');
    }
  }

  Future<void> _cancelRecording() async {
    _recTimer?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _sendRecording() async {
    if (!_recording) return;
    _recTimer?.cancel();
    final seconds = _recElapsed.inSeconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
    if (path == null) return;
    if (seconds < 1) {
      try {
        File(path).deleteSync();
      } catch (_) {}
      _showNotice('Record for a little longer, then send.');
      return;
    }
    await _send(extra: [File(path)]);
  }

  // ------------------------------------------------------------------ build

  Widget _buildPending() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _pending.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = _pending[i];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: p.kind == 'image'
                    ? Image.file(p.file, width: 62, height: 62, fit: BoxFit.cover)
                    : Container(
                        width: 62,
                        height: 62,
                        padding: const EdgeInsets.all(4),
                        color: _purple.withValues(alpha: 0.12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_kindIcon(p.kind), color: _purple),
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9)),
                          ],
                        ),
                      ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => setState(() => _pending.removeAt(i)),
                  child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    if (_recording) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 10, 10),
        child: Row(
          children: [
            IconButton(onPressed: _cancelRecording, icon: const Icon(Icons.delete_outline_rounded, color: _red), tooltip: 'Discard'),
            const Icon(Icons.fiber_manual_record, color: _red, size: 14),
            const SizedBox(width: 6),
            Text(_fmtDuration(_recElapsed), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            const Expanded(child: Text('Recording voice note...', style: TextStyle(color: Colors.grey, fontSize: 13))),
            _roundButton(Icons.send_rounded, _sendRecording),
          ],
        ),
      );
    }

    final hasContent = _text.text.trim().isNotEmpty || _pending.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(onPressed: _sending ? null : _openAttachMenu, icon: const Icon(Icons.attach_file_rounded), tooltip: 'Attach'),
          Expanded(
            child: TextField(
              controller: _text,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_sending)
            const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2.4, color: _red)))
          else
            _roundButton(hasContent ? Icons.send_rounded : Icons.mic_rounded, hasContent ? _send : _startRecording),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.conversation['display_name']?.toString() ?? '';
    final isGroup = widget.conversation['is_group'] == true;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 12, 8),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _openHeader,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        _ConversationAvatar(conversation: widget.conversation, radius: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (isGroup)
                                Text('${widget.conversation['member_count'] ?? 0} members · tap for info', style: const TextStyle(fontSize: 12, color: Colors.grey))
                              else if (_other != null)
                                Text(
                                  _other!.lastSeenLabel,
                                  style: TextStyle(fontSize: 12, color: _other!.online ? const Color(0xFF1E7E34) : Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('No messages yet. Say hello!', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      reverse: true,
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        return _MessageBubble(
                          message: message,
                          isGroup: isGroup,
                          onLongPress: () => _pickReaction(message),
                          onReactionTap: (emoji) => _react(message, emoji),
                          onOpenProfile: () => _openProfileOf(message),
                        );
                      },
                    ),
        ),
        if (_notice != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFDECEC),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(_notice!, style: const TextStyle(color: Color(0xFFB02A37), fontSize: 12.5)),
          ),
        if (_pending.isNotEmpty) _buildPending(),
        _buildComposer(),
      ],
    );
  }
}

// ===================================================================
// Message bubble: text, pictures, videos, voice notes, documents, location
// ===================================================================

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isGroup;
  final VoidCallback onLongPress;
  final ValueChanged<String> onReactionTap;
  final VoidCallback onOpenProfile;

  const _MessageBubble({
    required this.message,
    required this.isGroup,
    required this.onLongPress,
    required this.onReactionTap,
    required this.onOpenProfile,
  });

  void _openViewer(BuildContext context, List<Map<String, dynamic>> items, int index) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _MediaViewerPage(items: items, initialIndex: index)));
  }

  Widget _imageThumb(BuildContext context, Map<String, dynamic> m, List<Map<String, dynamic>> visual) {
    final url = m['url']?.toString() ?? '';
    return GestureDetector(
      onTap: () => _openViewer(context, visual, visual.indexOf(m)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 210,
          height: 210,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 210,
            height: 120,
            color: Colors.black12,
            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(width: 210, height: 210, color: Colors.black12, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ),
    );
  }

  Widget _videoThumb(BuildContext context, Map<String, dynamic> m, List<Map<String, dynamic>> visual) {
    return GestureDetector(
      onTap: () => _openViewer(context, visual, visual.indexOf(m)),
      child: VideoThumb(url: m['url']?.toString() ?? '', width: 210, height: 130),
    );
  }

  Widget _documentTile(Map<String, dynamic> m, bool sent) {
    final fg = sent ? Colors.white : Colors.black87;
    return InkWell(
      onTap: () => _openExternal(m['url']?.toString() ?? ''),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sent ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file_rounded, color: sent ? Colors.white : _purple, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_mediaName(m), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Tap to open', style: TextStyle(color: sent ? Colors.white70 : Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationCard(RegExpMatch match, bool sent) {
    final lat = match.group(1)!;
    final lng = match.group(2)!;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    return InkWell(
      onTap: () => _openExternal(url),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 230,
        decoration: BoxDecoration(color: sent ? Colors.white : const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFCFE0FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: const Icon(Icons.location_on_rounded, color: _red, size: 40),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shared location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.black87)),
                        Text('$lat, $lng', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Text('Open', style: TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.w700, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sent = message['is_mine'] == true;
    var text = message['text']?.toString() ?? '';
    final media = ((message['media'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final senderName = message['sender_name']?.toString() ?? '';
    final sticker = message['sticker']?.toString() ?? '';

    final locationMatch = _locationRegex.firstMatch(text);
    if (locationMatch != null) {
      text = text.replaceAll(_locationRegex, '').replaceAll('📍 My location', '').trim();
    }
    final visual = media.where((m) {
      final k = _mediaKind(m);
      return k == 'image' || k == 'video';
    }).toList();
    final fg = sent ? Colors.white : Colors.black87;
    final timeText = _fmtTime(message['created_at']?.toString());

    // Tap the sender's name (or picture) to open their profile.
    final nameLabel = (!sent && senderName.isNotEmpty)
        ? GestureDetector(
            onTap: onOpenProfile,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _purple)),
            ),
          )
        : null;

    Widget bubble;
    if (sticker.isNotEmpty && text.isEmpty && media.isEmpty && locationMatch == null) {
      // A sticker on its own: no bubble, just the sticker.
      bubble = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: sent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (nameLabel != null) nameLabel,
            StickerView(stickerKey: sticker, size: 130),
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(timeText, style: const TextStyle(fontSize: 10, color: Colors.grey))),
          ],
        ),
      );
    } else {
      final children = <Widget>[
        if (nameLabel != null) nameLabel,
        if (sticker.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: StickerView(stickerKey: sticker, size: 110)),
        for (final m in media)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: () {
              switch (_mediaKind(m)) {
                case 'video':
                  return _videoThumb(context, m, visual);
                case 'audio':
                  return _AudioBubble(url: m['url']?.toString() ?? '', sent: sent);
                case 'document':
                  return _documentTile(m, sent);
                default:
                  return _imageThumb(context, m, visual);
              }
            }(),
          ),
        if (locationMatch != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: _locationCard(locationMatch, sent)),
        if (text.isNotEmpty) Text(text, style: TextStyle(color: fg, fontSize: 14.5, height: 1.3)),
        const SizedBox(height: 3),
        Align(
          alignment: Alignment.centerRight,
          child: Text(timeText, style: TextStyle(fontSize: 10, color: sent ? Colors.white70 : Colors.grey)),
        ),
      ];
      bubble = Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: sent ? _red : Colors.white,
          border: sent ? null : Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
    }

    // Press and hold anywhere on the message to react to it.
    final column = Column(
      crossAxisAlignment: sent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(onLongPress: onLongPress, child: bubble),
        ReactionBar(reactions: message['reactions'], onToggle: onReactionTap),
      ],
    );

    final showAvatar = !sent && isGroup;
    return Align(
      alignment: sent ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        child: showAvatar
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: onOpenProfile,
                      child: UserAvatar(name: senderName, photoUrl: message['sender_photo']?.toString(), radius: 14),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: column),
                ],
              )
            : column,
      ),
    );
  }
}

/// Plays a voice note or audio file inside the chat.
class _AudioBubble extends StatefulWidget {
  final String url;
  final bool sent;
  const _AudioBubble({required this.url, required this.sent});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _pos = Duration.zero;
          _playing = false;
        });
      }
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
      } else if (_pos > Duration.zero) {
        await _player.resume();
      } else {
        await _player.play(UrlSource(widget.url));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.sent ? Colors.white : _red;
    final inactive = widget.sent ? Colors.white38 : Colors.grey.shade300;
    final textColor = widget.sent ? Colors.white70 : Colors.grey;
    final total = _dur.inMilliseconds;
    final progress = total == 0 ? 0.0 : (_pos.inMilliseconds / total).clamp(0.0, 1.0);

    return SizedBox(
      width: 230,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: widget.sent ? Colors.white : _red, shape: BoxShape.circle),
              child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: widget.sent ? _red : Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: progress,
                    activeColor: active,
                    inactiveColor: inactive,
                    onChanged: total == 0 ? null : (v) => _player.seek(Duration(milliseconds: (v * total).round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    '${_fmtDuration(_pos)} / ${_fmtDuration(_dur)}',
                    style: TextStyle(fontSize: 10.5, color: textColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Full-screen viewer for pictures and videos
// ===================================================================

class _MediaViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialIndex;
  const _MediaViewerPage({required this.items, required this.initialIndex});

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  late final PageController _pages = PageController(initialPage: math.max(widget.initialIndex, 0));
  late int _index = math.max(widget.initialIndex, 0);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: items.length > 1 ? Text('${_index + 1} / ${items.length}', style: const TextStyle(fontSize: 15)) : null,
        actions: [
          IconButton(
            tooltip: 'Open outside the app',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => _openExternal(items[_index]['url']?.toString() ?? ''),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final m = items[i];
          final url = m['url']?.toString() ?? '';
          if (_mediaKind(m) == 'video') {
            return VideoViewer(key: ValueKey(url), url: url, autoPlay: items.length == 1);
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 60),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ===================================================================
// New chat: search a person, then choose what to do
// ===================================================================

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet();

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _groupName = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  final Map<int, Map<String, dynamic>> _selected = {};
  bool _groupMode = false;
  File? _groupIcon;
  bool _searching = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = true;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _groupName.dispose();
    super.dispose();
  }

  void _setMessage(String? text, {bool error = true}) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _messageIsError = error;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await ChatService.searchUsers(query.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } on ChatException catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      _setMessage(e.message);
    }
  }

  void _toggle(Map<String, dynamic> user) {
    final id = user['id'] as int;
    setState(() {
      if (_selected.containsKey(id)) {
        _selected.remove(id);
      } else {
        _selected[id] = user;
      }
    });
  }

  Future<void> _onUserTap(Map<String, dynamic> user) async {
    if (_groupMode) {
      _toggle(user);
      return;
    }
    FocusScope.of(context).unfocus();
    final name = user['name']?.toString() ?? '';
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  UserAvatar(name: name, photoUrl: user['photo_url']?.toString(), radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(user['email']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: _purple),
              title: const Text('View profile'),
              onTap: () => Navigator.pop(sheetContext, 'profile'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_rounded, color: _purple),
              title: const Text('Start chat'),
              onTap: () => Navigator.pop(sheetContext, 'chat'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_rounded, color: _purple),
              title: const Text('Start group chat'),
              onTap: () => Navigator.pop(sheetContext, 'group'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_rounded, color: _red),
              title: const Text('Add as emergency contact'),
              onTap: () => Navigator.pop(sheetContext, 'contact'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'profile':
        await showUserProfileSheet(
          context,
          userId: user['id'] as int,
          name: name,
          photoUrl: user['photo_url']?.toString(),
        );
        break;
      case 'chat':
        await _startChat(user);
        break;
      case 'group':
        setState(() {
          _groupMode = true;
          _selected[user['id'] as int] = user;
          _message = null;
        });
        break;
      case 'contact':
        await _addAsContact(user);
        break;
    }
  }

  Future<void> _startChat(Map<String, dynamic> user) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final conversation = await ChatService.createConversation(memberIds: [user['id'] as int]);
      if (!mounted) return;
      Navigator.pop(context, conversation);
    } on ChatException catch (e) {
      if (mounted) setState(() => _busy = false);
      _setMessage(e.message);
    }
  }

  Future<void> _addAsContact(Map<String, dynamic> user) async {
    final name = user['name']?.toString() ?? 'this person';
    final relationship = await _pickRelationship(context, name);
    if (relationship == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ContactsService.addUserAsContact(user['id'] as int, relationship: relationship);
      if (mounted) setState(() => _busy = false);
      _setMessage('Request sent. $name will be your emergency contact once they accept.', error: false);
    } on ContactsException catch (e) {
      if (mounted) setState(() => _busy = false);
      _setMessage(e.message);
    }
  }

  Future<void> _pickGroupIcon() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1024);
      if (x != null && mounted) setState(() => _groupIcon = File(x.path));
    } catch (_) {
      _setMessage('Could not open your photos.');
    }
  }

  Future<void> _createGroup() async {
    if (_selected.isEmpty) return;
    if (_groupName.text.trim().isEmpty) {
      _setMessage('Give the group a name.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      var conversation = await ChatService.createConversation(
        memberIds: _selected.keys.toList(),
        isGroup: true,
        name: _groupName.text.trim(),
      );
      final icon = _groupIcon;
      if (icon != null) {
        try {
          conversation = await ChatService.setGroupIcon(conversation['id'] as int, icon);
        } on ChatException {
          // The group is created; the picture can be added later from the group's info.
        }
      }
      if (!mounted) return;
      Navigator.pop(context, conversation);
    } on ChatException catch (e) {
      if (mounted) setState(() => _busy = false);
      _setMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                Expanded(child: Text(_groupMode ? 'New Group' : 'New Chat', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                if (_groupMode)
                  TextButton(
                    onPressed: () => setState(() {
                      _groupMode = false;
                      _groupIcon = null;
                      _selected.clear();
                    }),
                    child: const Text('Cancel group'),
                  ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          if (_groupMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _busy ? null : _pickGroupIcon,
                    child: _groupIcon != null
                        ? ClipOval(child: Image.file(_groupIcon!, width: 48, height: 48, fit: BoxFit.cover))
                        : const CircleAvatar(
                            radius: 24,
                            backgroundColor: _purple,
                            child: Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _groupName,
                      decoration: InputDecoration(hintText: 'Group name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ],
              ),
            ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  children: _selected.values
                      .map((u) => Chip(label: Text(u['name']?.toString() ?? ''), onDeleted: () => _toggle(u)))
                      .toList(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: _groupMode ? 'Search to add more people...' : 'Search by name or email...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(_message!, style: TextStyle(fontSize: 12.5, color: _messageIsError ? const Color(0xFFB02A37) : const Color(0xFF1E7E34))),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(child: Text('Search for someone to chat with', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final u = _results[index];
                          final selected = _selected.containsKey(u['id']);
                          final name = u['name']?.toString() ?? '';
                          return ListTile(
                            onTap: _busy ? null : () => _onUserTap(u),
                            leading: UserAvatar(name: name, photoUrl: u['photo_url']?.toString(), radius: 20),
                            title: Text(name),
                            subtitle: Text(u['email']?.toString() ?? ''),
                            trailing: _groupMode
                                ? (selected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF28A745)) : null)
                                : const Icon(Icons.more_horiz_rounded, color: Colors.grey),
                          );
                        },
                      ),
          ),
          if (_groupMode)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _purple, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: (_selected.isEmpty || _busy) ? null : _createGroup,
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Create Group (${_selected.length})', style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


// ===================================================================
// Group info: picture, name and members
// ===================================================================

class _GroupInfoSheet extends StatefulWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onChanged;
  const _GroupInfoSheet({required this.conversation, required this.onChanged});

  @override
  State<_GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends State<_GroupInfoSheet> {
  bool _busy = false;
  String? _error;

  int get _id => widget.conversation['id'] as int;

  void _apply(Map<String, dynamic> updated) {
    widget.conversation['icon_url'] = updated['icon_url'];
    widget.conversation['avatar_url'] = updated['avatar_url'];
    widget.conversation['members'] = updated['members'];
    widget.onChanged();
  }

  Future<void> _changeIcon() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1024);
      if (x == null || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      final updated = await ChatService.setGroupIcon(_id, File(x.path));
      if (!mounted) return;
      setState(() {
        _apply(updated);
        _busy = false;
      });
    } on ChatException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not open your photos.';
        });
      }
    }
  }

  Future<void> _removeIcon() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ChatService.removeGroupIcon(_id);
      if (!mounted) return;
      setState(() {
        _apply(updated);
        _busy = false;
      });
    } on ChatException catch (e) {
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
    final members = ((widget.conversation['members'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final hasIcon = (widget.conversation['icon_url']?.toString() ?? '').isNotEmpty;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Center(
            child: Stack(
              children: [
                _ConversationAvatar(conversation: widget.conversation, radius: 46),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: _purple,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _busy ? null : _changeIcon,
                      child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.conversation['display_name']?.toString() ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('${members.length} members', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB02A37), fontSize: 12.5)),
            ),
          if (hasIcon)
            Center(child: TextButton(onPressed: _busy ? null : _removeIcon, child: const Text('Remove group picture'))),
          const Divider(height: 28),
          const Text('Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          for (final m in members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(name: m['name']?.toString() ?? '', photoUrl: m['photo_url']?.toString(), radius: 20),
              title: Text(m['name']?.toString() ?? ''),
              onTap: () {
                final id = (m['id'] as num?)?.toInt();
                if (id == null) return;
                showUserProfileSheet(context, userId: id, name: m['name']?.toString() ?? '', photoUrl: m['photo_url']?.toString());
              },
            ),
        ],
      ),
    );
  }
}