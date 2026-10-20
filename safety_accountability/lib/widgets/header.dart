import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/anonymous_page.dart';
import '../screens/log_page.dart';
import '../screens/contacts_page.dart';
import '../screens/events_page.dart';
import '../screens/reports_page.dart';
import '../app_settings.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../app_nav.dart';
import '../services/sound_service.dart';
import '../services/quick_sos_service.dart';
import 'quick_sos_tile.dart';
import 'notifications_sheet.dart';
import 'messages_sheet.dart';


class Header extends StatefulWidget implements PreferredSizeWidget {
  const Header({super.key});

  @override
  State<Header> createState() => _HeaderState();

  @override
  Size get preferredSize => const Size.fromHeight(64);
}

class _HeaderState extends State<Header> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _hamburgerKey = GlobalKey();

  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _conversations = [];
  Timer? _chatPollTimer;
  Timer? _notifPollTimer;

  final Set<int> _seenNotificationIds = {};
  bool _notificationsPrimed = false;

  late final AnimationController _ringCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _chatRingCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int? _lastUnreadChats;

  void _ring(AnimationController ctrl) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    ctrl.forward(from: 0);
  }

  int get _unreadNotifs => _notifications.where((n) => n['read'] != true).length;
  int get _unreadChats => _conversations.fold<int>(0, (sum, c) => sum + ((c['unread_count'] as int?) ?? 0));

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadNotifications();
    // Keeps both badges current even while their sheets are closed — the
    // same polling pattern used everywhere else in the app (no
    // WebSockets/Channels set up on the backend yet).
    _chatPollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadConversations());
    _notifPollTimer = Timer.periodic(const Duration(seconds: 12), (_) => _loadNotifications());
       AppNav.chatRequest.addListener(_onChatRequest);
    QuickSosService.ensureRunning();
  }

  @override
  void dispose() {
    _chatPollTimer?.cancel();
    _notifPollTimer?.cancel();
    AppNav.chatRequest.removeListener(_onChatRequest);
    _ringCtrl.dispose();
    _chatRingCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await ChatService.listConversations();
      if (!mounted) return;
      final before = _lastUnreadChats;
      setState(() => _conversations = conversations);
      final now = _unreadChats;
      _lastUnreadChats = now;
      if (before != null && now > before) _ring(_chatRingCtrl);
    } on ChatException {
      // Silent — this is a background badge refresh, not a user action.
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await NotificationService.list();
      if (!mounted) return;
      // Sound when a NEW unread notification arrives (never on the first load).
      final fresh = notifications.where((n) => n['read'] != true && !_seenNotificationIds.contains(n['id'])).toList();
      if (_notificationsPrimed && fresh.isNotEmpty) SoundService.notify();
      for (final n in notifications) {
        final id = n['id'];
        if (id is int) _seenNotificationIds.add(id);
      }
      _notificationsPrimed = true;
      setState(() => _notifications = notifications);
    } on NotificationServiceException {
      // Silent — this is a background badge refresh, not a user action.
    }
  }

  // Another screen (a profile, a notification) asked to open a chat.
  void _onChatRequest() {
    final conversation = AppNav.chatRequest.value;
    if (conversation == null) return;
    AppNav.chatRequest.value = null;
    _openMessages(initial: conversation);
  }

  void _openHamburgerMenu() {
    // Find the hamburger button's real position on screen so the menu
    // opens directly under/beside it, instead of a guessed coordinate.
    final RenderBox button = _hamburgerKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay);

    final RelativeRect position = RelativeRect.fromLTRB(
      topLeft.dx,
      bottomRight.dy,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - bottomRight.dy,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(value: 'contacts', child: Text('Emergency Contacts')),
        PopupMenuItem(value: 'reports', child: Text('View Reports')),
        PopupMenuItem(value: 'anonymous', child: Text('Anonymous Reporting')),
        PopupMenuItem(value: 'log', child: Text('Log Activity')),
        PopupMenuItem(value: 'events', child: Text('Events')),
      ],
    ).then((value) {
      // The menu's Future resolves after the person taps an item, which is
      // an async gap — guard with `mounted` before touching `context` again,
      // in case this Header was removed from the tree while the menu was open.
      if (!mounted) return;
      if (value == 'anonymous') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Anonymous Reporting'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
              ),
              body: const SafeArea(child: AnonymousPage()),
            ),
          ),
        );
      } else if (value == 'log') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Log Activity'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
              ),
              body: const SafeArea(child: LogPage()),
            ),
          ),
        );
      } else if (value == 'contacts') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
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
      } else if (value == 'events') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Events'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
              ),
              body: const SafeArea(child: EventsPage()),
            ),
          ),
        );
      } else if (value == 'reports') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Reports & News'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
              ),
              body: const SafeArea(child: ReportsPage()),
            ),
          ),
        );
      }
    });
  }

  Future<void> _openNotifications() async {
    final tapped = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => NotificationsSheet(
        notifications: _notifications,
        onMarkAllRead: () async {
          setState(() {
            _notifications = _notifications.map((n) => {...n, 'read': true}).toList();
          });
          try {
            await NotificationService.markAllRead();
          } on NotificationServiceException {
            // Already marked read locally — the next poll reconciles it.
          }
        },
      ),
    );
    _loadNotifications();
    if (tapped != null && mounted) {
      await NotificationRouter.open(context, tapped, onChanged: _loadNotifications);
    }
  }

  void _openMessages({Map<String, dynamic>? initial}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => MessagesSheet(
        conversations: _conversations,
        initialConversation: initial,
        onConversationsChanged: (updated) => setState(() => _conversations = updated),
      ),
    ).whenComplete(_loadConversations);
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Row(
        children: [
          IconButton(key: _hamburgerKey, icon: const Icon(Icons.menu_rounded), onPressed: _openHamburgerMenu),
          _BadgeIcon(
            icon: Icons.notifications_none_rounded,
            count: _unreadNotifs,
            ring: _ringCtrl,
            onTap: _openNotifications,
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _openSettings),
          _BadgeIcon(
            icon: Icons.chat_bubble_outline_rounded,
            count: _unreadChats,
            ring: _chatRingCtrl,
            onTap: _openMessages,
          ),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final Animation<double>? ring;

  const _BadgeIcon({required this.icon, required this.count, required this.onTap, this.ring});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ring == null
            ? IconButton(icon: Icon(icon), onPressed: onTap)
            : AnimatedBuilder(
                animation: ring!,
                builder: (context, child) => Transform.rotate(
                  angle: math.sin(ring!.value * math.pi * 8) * 0.35 * (1 - ring!.value),
                  child: child,
                ),
                child: IconButton(icon: Icon(icon), onPressed: onTap),
              ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}



// ===== SETTINGS SHEET =====
// Every button here actually opens the thing its label promises: a real
// picker, a real toggle sheet, or a confirmation — nothing is a dead tap.
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  Map<String, dynamic>? _user;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final cached = await AuthService.getCachedUser();
    if (!mounted) return;
    setState(() {
      _user = cached;
    });
  }

  String get _displayName {
    final name = _user?['full_name'] as String?;
    return (name != null && name.trim().isNotEmpty) ? name : 'User';
  }

  String get _displayEmail {
    final email = _user?['email'] as String?;
    return (email != null && email.trim().isNotEmpty) ? email : '';
  }

  String get _initials {
    final name = _displayName.trim();
    if (name.isEmpty || name == 'User') return 'U';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String? get _photoUrl {
    final url = _user?['profile_photo_url'] as String?;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _choosePhotoSource() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text('Profile picture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (_photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                title: const Text('Remove picture', style: TextStyle(color: Color(0xFFDC2626))),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      await _removePhoto();
    } else {
      await _pickAndUpload(choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } catch (_) {
      _toast('Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}.');
      return;
    }
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final user = await AccountService.uploadProfilePhoto(File(picked.path));
      if (!mounted) return;
      setState(() => _user = user);
      _toast('Profile picture updated.');
    } on AccountException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      final user = await AccountService.removeProfilePhoto();
      if (!mounted) return;
      setState(() => _user = user);
      _toast('Profile picture removed.');
    } on AccountException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _avatar() {
    final initialsAvatar = CircleAvatar(
      radius: 40,
      backgroundColor: Colors.white24,
      child: Text(_initials, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
    );

    final url = _photoUrl;
    final Widget face = url == null
        ? initialsAvatar
        : ClipOval(
            child: Image.network(
              url,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : SizedBox(
                      width: 80,
                      height: 80,
                      child: Container(color: Colors.white24, child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                    ),
              errorBuilder: (_, _, _) => initialsAvatar,
            ),
          );

    return GestureDetector(
      onTap: _uploadingPhoto ? null : _choosePhotoSource,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white54),
            child: face,
          ),
          if (_uploadingPhoto)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
              ),
            ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4)],
              ),
              child: const Icon(Icons.photo_camera_rounded, size: 16, color: Color(0xFF667EEA)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                _avatar(),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _uploadingPhoto ? null : _choosePhotoSource,
                  style: TextButton.styleFrom(foregroundColor: Colors.white70, padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                  child: Text(_photoUrl == null ? 'Add profile picture' : 'Change picture', style: const TextStyle(fontSize: 12.5)),
                ),
                const SizedBox(height: 6),
                Text(_displayName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                if (_displayEmail.isNotEmpty)
                  Text(_displayEmail, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeNotifier,
                  builder: (context, mode, _) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: SwitchListTile(
                      value: mode == ThemeMode.dark,
                      onChanged: (v) => themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
                      activeThumbColor: const Color(0xFF667EEA),
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Dark Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Switches the whole app to a darker theme', style: TextStyle(fontSize: 11.5)),
                    ),
                  ),
                ),
                ValueListenableBuilder<String>(
                  valueListenable: languageNotifier,
                  builder: (context, lang, _) => _SettingsButton(
                    icon: Icons.language_outlined,
                    label: 'Language & Region',
                    trailingText: lang,
                    onTap: () => _openLanguagePicker(context),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                _SettingsButton(
                  icon: Icons.lock_outline,
                  label: 'Change Password',
                  onTap: () => _openChangePassword(context),
                ),
                _SettingsButton(
                  icon: Icons.shield_outlined,
                  label: 'Privacy Settings',
                  onTap: () => _openPrivacySettings(context),
                ),
                                _SettingsButton(
                  icon: Icons.notifications_outlined,
                  label: 'Notification Preferences',
                  onTap: () => _openNotificationPrefs(context),
                ),
                const QuickSosTile(),
                const SizedBox(height: 16),
                const Text('Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                _SettingsButton(
                  icon: Icons.help_outline,
                  label: 'Help Center',
                  onTap: () => _openHelpCenter(context),
                ),
                _SettingsButton(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  danger: true,
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final String? trailingText;
  final VoidCallback? onTap;

  const _SettingsButton({
    required this.icon,
    required this.label,
    this.danger = false,
    this.trailingText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFF374151);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          side: BorderSide(color: danger ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB)),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            if (trailingText != null) ...[
              Text(trailingText!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ---- Settings sub-sheets & dialogs ----
// Kept as plain functions (not methods) so any widget in this file can open
// them with just a BuildContext — no need to thread callbacks around.

void _openLanguagePicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.35,
      expand: false,
      builder: (context, scrollController) => ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, selected, _) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Language & Region', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
              "Choose the language you're most comfortable with. Emergency and Contacts screens are translated so far; the rest of the app is coming next.",
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
            ),
            const SizedBox(height: 10),
            // RadioGroup owns the selection for every RadioListTile inside
            // it, so the tiles themselves only need a `value`.
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) languageNotifier.value = value;
                Navigator.pop(sheetContext);
              },
              child: Column(
                children: appLanguages
                    .map((lang) => RadioListTile<String>(
                          value: lang,
                          activeColor: const Color(0xFF667EEA),
                          contentPadding: EdgeInsets.zero,
                          title: Text(lang),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _openChangePassword(BuildContext context) {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  String? error;
  bool submitting = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> submit() async {
          if (next.text.trim().isEmpty || next.text != confirm.text) {
            setDialogState(() => error = "New password and confirmation must match");
            return;
          }
          setDialogState(() {
            error = null;
            submitting = true;
          });
          try {
            await AccountService.changePassword(
              currentPassword: current.text,
              newPassword: next.text,
              confirmNewPassword: confirm.text,
            );
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            // The backend invalidates the old session token on a password
            // change — rather than quietly juggling a new token, send the
            // person back through a real login with their new password.
            isLoggedIn.value = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password changed. Please log in again with your new password.')),
            );
          } on AccountException catch (e) {
            setDialogState(() {
              error = e.message;
              submitting = false;
            });
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA)),
              onPressed: submitting ? null : submit,
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ),
  );
}

void _openPrivacySettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Privacy Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('What you share, and with whom', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: PrivacyPrefs.shareLocationWithContacts,
            builder: (context, value, _) => SwitchListTile(
              value: value,
              onChanged: (v) => PrivacyPrefs.shareLocationWithContacts.value = v,
              activeThumbColor: const Color(0xFF667EEA),
              contentPadding: EdgeInsets.zero,
              title: const Text('Share live location with emergency contacts', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Needed for trip sharing and panic alerts to work', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: PrivacyPrefs.showProfileToCommunity,
            builder: (context, value, _) => SwitchListTile(
              value: value,
              onChanged: (v) => PrivacyPrefs.showProfileToCommunity.value = v,
              activeThumbColor: const Color(0xFF667EEA),
              contentPadding: EdgeInsets.zero,
              title: const Text('Show my profile on the Community feed', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Turn off to post and comment without your name showing', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: PrivacyPrefs.anonymousReportsStayAnonymous,
            builder: (context, value, _) => SwitchListTile(
              value: value,
              onChanged: (v) => PrivacyPrefs.anonymousReportsStayAnonymous.value = v,
              activeThumbColor: const Color(0xFF667EEA),
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep Anonymous Reports fully anonymous', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Even admins only ever see the case, never your identity', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            ),
          ),
        ],
      ),
    ),
  );
}

void _openNotificationPrefs(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.8,
      minChildSize: 0.35,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: NotificationPrefs.emergencyAlerts,
            builder: (context, value, _) => SwitchListTile(
              value: value,
              onChanged: (v) => NotificationPrefs.emergencyAlerts.value = v,
              activeThumbColor: const Color(0xFF667EEA),
              contentPadding: EdgeInsets.zero,
              title: const Text('Emergency Alerts', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Strongly recommended to keep this on', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: NotificationPrefs.communityPosts,
            builder: (context, value, _) => SwitchListTile(
              value: value,
              onChanged: (v) => NotificationPrefs.communityPosts.value = v,
              activeThumbColor: const Color(0xFF667EEA),
              contentPadding: EdgeInsets.zero,
              title: const Text('Community Posts', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('New posts and warnings from your area', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: NotificationPrefs.messages,
            builder: (context, value, _) => SwitchListTile(
              value: value,
              onChanged: (v) => NotificationPrefs.messages.value = v,
              activeThumbColor: const Color(0xFF667EEA),
              contentPadding: EdgeInsets.zero,
              title: const Text('Messages', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Direct messages from contacts and groups', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: NotificationPrefs.weeklyReports,
            builder: (context, value, _) => SwitchListTile(
              value: value,
              onChanged: (v) => NotificationPrefs.weeklyReports.value = v,
              activeThumbColor: const Color(0xFF667EEA),
              contentPadding: EdgeInsets.zero,
              title: const Text('Weekly Safety Reports', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: const Text('Summary of reports and stats in your area', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            ),
          ),
        ],
      ),
    ),
  );
}

void _openHelpCenter(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Help Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Quick answers and ways to reach real help', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 14),
          _HelpTile(icon: Icons.local_police_rounded, title: 'SAPS Emergency', value: '10111', onTap: () => _launchTel('10111')),
          _HelpTile(icon: Icons.favorite_rounded, title: 'GBV Command Centre', value: '0800 428 428', onTap: () => _launchTel('0800428428')),
          _HelpTile(icon: Icons.support_agent_rounded, title: 'App Support', value: 'support@safetyapp.co.za', onTap: () => _launchEmail('support@safetyapp.co.za')),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          const Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const _FaqItem(
            q: 'How do emergency contacts get "Protected" status?',
            a: 'They need the app installed too — once they accept your invite, they can receive your live trip details and panic alerts.',
          ),
          const _FaqItem(
            q: 'Does the panic button call the police directly?',
            a: 'Right now it notifies your community and emergency contacts. Direct authority dispatch needs a backend integration, which is planned next.',
          ),
          const _FaqItem(
            q: 'Can I use the app without data or Wi-Fi?',
            a: 'Not yet — most features need an internet connection. Offline/SMS fallback is on the roadmap.',
          ),
        ],
      ),
    ),
  );
}

void _confirmLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Log Out?'),
      content: const Text("You'll need to sign in again to use the app."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () {
            Navigator.pop(dialogContext); // close the confirmation
            Navigator.pop(context); // close the Settings sheet
            // main.dart is watching this — flipping it swaps the whole
            // app straight to AuthPage.
            isLoggedIn.value = false;
          },
          child: const Text('Log Out', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Future<void> _launchTel(String number) async {
  final uri = Uri.parse('tel:$number');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Future<void> _launchEmail(String email) async {
  final uri = Uri.parse('mailto:$email');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _HelpTile({required this.icon, required this.title, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF667EEA).withValues(alpha: 0.12),
        child: Icon(icon, color: const Color(0xFF667EEA), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      subtitle: Text(value, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(q, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(a, style: const TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4)),
          ),
        ],
      ),
    );
  }
}