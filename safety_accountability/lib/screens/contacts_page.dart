import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/contacts_service.dart';
import '../services/live_location_service.dart';
import '../l10n/generated/app_localizations.dart';

const List<String> _relationshipKeys = ['parent', 'sibling', 'partner', 'friend', 'roommate', 'colleague', 'other'];

String _relationshipLabel(BuildContext context, String key) {
  final l = AppLocalizations.of(context)!;
  switch (key) {
    case 'parent':
      return l.relationshipParent;
    case 'sibling':
      return l.relationshipSibling;
    case 'partner':
      return l.relationshipPartner;
    case 'friend':
      return l.relationshipFriend;
    case 'roommate':
      return l.relationshipRoommate;
    case 'colleague':
      return l.relationshipColleague;
    default:
      return l.relationshipOther;
  }
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _requests = [];
  final Set<int> _respondingIds = {};
  bool _loading = true;
  String? _error;
  bool _sharingBusy = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    // Sync the sharing switch with what Django has saved.
    LiveLocationService.refresh().catchError((_) {});
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ContactsService.listContacts(),
        // A problem loading requests should not hide your own contacts.
        ContactsService.incomingRequests().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _contacts = results[0];
        _requests = results[1];
        _loading = false;
      });
    } on ContactsException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _respond(Map<String, dynamic> request, bool accept) async {
    final id = request['id'] as int;
    if (_respondingIds.contains(id)) return;
    final name = request['from_name']?.toString() ?? 'this person';
    setState(() => _respondingIds.add(id));
    try {
      await ContactsService.respondToRequest(id, accept: accept);
      if (!mounted) return;
      setState(() => _requests = _requests.where((r) => r['id'] != id).toList());
      _toast(accept ? 'You are now an emergency contact for $name.' : 'Request declined.');
    } on ContactsException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _respondingIds.remove(id));
    }
  }

  Future<void> _toggleSharing(bool wantOn) async {
    if (_sharingBusy) return;

    int? minutes;
    if (wantOn) {
      final choice = await showDialog<int>(
        context: context,
        builder: (_) => const _ShareDurationDialog(),
      );
      if (choice == null) return; // cancelled
      minutes = choice == 0 ? null : choice; // 0 means "until I turn it off"
    }
    if (!mounted) return;

    setState(() => _sharingBusy = true);
    try {
      await LiveLocationService.setSharing(enabled: wantOn, durationMinutes: minutes);
    } on LiveLocationException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _sharingBusy = false);
    }
  }

  Future<void> _addFromContacts() async {
    final granted = await FlutterContacts.requestPermission();
    if (!granted) {
      _toast('Contacts permission is needed to add an emergency contact.');
      return;
    }

    final allContacts = await FlutterContacts.getContacts(withProperties: true);
    final withPhones = allContacts.where((c) => c.phones.isNotEmpty).toList();

    if (!mounted) return;
    final Contact? picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _ContactPickerSheet(contacts: withPhones),
    );
    if (picked == null) return;

    final name = picked.displayName;
    final phone = picked.phones.first.number;

    if (!mounted) return;
    final relationshipKey = await showDialog<String>(
      context: context,
      builder: (context) => _RelationshipDialog(name: name),
    );
    if (relationshipKey == null) return;
    if (!mounted) return;
    final relationshipLabel = _relationshipLabel(context, relationshipKey);

    try {
      final created = await ContactsService.addContact(name: name, phoneNumber: phone, relationship: relationshipLabel);
      if (!mounted) return;
      setState(() => _contacts = [created, ..._contacts]);
      if (created['has_app'] == true) {
        _toast("Request sent. $name will show as Protected once they accept.");
      }
    } on ContactsException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _sendInvite(Map<String, dynamic> contact) async {
    final firstName = (contact['name'] as String).split(' ').first;
    final message = Uri.encodeComponent(
      "Hi $firstName, I've added you as my emergency contact on Safety & Accountability. "
      "Please install the app so you can receive my live alerts: https://safetyapp.example.com/download",
    );
    final uri = Uri.parse('sms:${contact['phone_number']}?body=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('Could not open messages app.');
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _removeContact(int id) async {
    final previous = _contacts;
    setState(() => _contacts = _contacts.where((c) => c['id'] != id).toList());
    try {
      await ContactsService.deleteContact(id);
    } on ContactsException catch (e) {
      if (!mounted) return;
      setState(() => _contacts = previous);
      _toast(e.message);
    }
  }

  // Protected = has the app AND accepted your request.
  bool _isProtected(Map<String, dynamic> c) =>
      c['has_app'] == true && (c['status']?.toString() ?? 'accepted') == 'accepted';

  int get _protectedCount => _contacts.where(_isProtected).length;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      color: const Color(0xFFF5F7FA),
      child: RefreshIndicator(
        onRefresh: _loadContacts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHero(context),
            if (_requests.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRequests(),
            ],
            const SizedBox(height: 16),
            _buildWhyBanner(context),
            const SizedBox(height: 12),
            _buildSharingCard(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.yourCircle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text('${_contacts.length} contact${_contacts.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildErrorState(context)
            else if (_contacts.isEmpty)
              _buildEmptyState(context)
            else
              ..._contacts.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ContactCard(
                      contact: c,
                      onCall: () => _call(c['phone_number'] as String),
                      onInvite: () => _sendInvite(c),
                      onDelete: () => _removeContact(c['id'] as int),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ requests

  Widget _buildRequests() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667EEA), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_reg_rounded, color: Color(0xFF667EEA)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Requests for you (${_requests.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'If you accept, you will get their emergency alerts and see the activities they log. They will see your live location only when you turn sharing on.',
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
          ),
          ..._requests.map(_requestRow),
        ],
      ),
    );
  }

  Widget _requestRow(Map<String, dynamic> r) {
    final id = r['id'] as int;
    final busy = _respondingIds.contains(id);
    final name = r['from_name']?.toString() ?? 'Someone';
    final photo = r['from_photo']?.toString();
    final relation = r['relationship']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF667EEA),
            backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
            child: (photo != null && photo.isNotEmpty)
                ? null
                : Text(_initialsOf(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  relation.isEmpty ? 'wants to add you as an emergency contact' : 'listed you as: $relation',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            _circleButton(Icons.close_rounded, const Color(0xFFDC3545), 'Decline', () => _respond(r, false)),
            const SizedBox(width: 10),
            _circleButton(Icons.check_rounded, const Color(0xFF28A745), 'Accept', () => _respond(r, true)),
          ],
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  // ------------------------------------------------------- live location

  Widget _buildSharingCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: LiveLocationService.isSharing,
      builder: (context, sharing, _) {
        return ValueListenableBuilder<DateTime?>(
          valueListenable: LiveLocationService.sharingUntil,
          builder: (context, until, _) {
            String subtitle;
            if (!sharing) {
              subtitle = 'Off. When on, people who added you as an emergency contact can see where you are on their map.';
            } else if (until == null) {
              subtitle = 'On until you turn it off. Works while the app is open.';
            } else {
              final hh = until.hour.toString().padLeft(2, '0');
              final mm = until.minute.toString().padLeft(2, '0');
              subtitle = 'On until $hh:$mm. Works while the app is open.';
            }
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sharing ? const Color(0xFF28A745) : const Color(0xFFE0E0E0), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(
                    sharing ? Icons.my_location_rounded : Icons.location_off_rounded,
                    color: sharing ? const Color(0xFF28A745) : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Share my live location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.35)),
                      ],
                    ),
                  ),
                  Switch(
                    value: sharing,
                    onChanged: _sharingBusy ? null : _toggleSharing,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHero(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF667EEA).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.emergencyContactsTitle, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(l.emergencyContactsSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _statPill('$_protectedCount', l.protectedLabel, Icons.verified_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _statPill('${_contacts.length - _protectedCount}', l.pendingLabel, Icons.hourglass_top_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF667EEA),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _addFromContacts,
              icon: const Icon(Icons.person_add_rounded, size: 19),
              label: Text(l.addFromContacts, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhyBanner(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFF007BFF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.contactsWhyBanner,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1A3D7C), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(40),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.people_outline_rounded, size: 46, color: Colors.grey),
          const SizedBox(height: 14),
          Text(l.noContactsYet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(l.addSomeoneYouTrust, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(28),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          Text(_error ?? l.couldNotLoadContacts, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadContacts, child: Text(l.tryAgainLabelFallback(context))),
        ],
      ),
    );
  }
}

extension on AppLocalizations {
  // emergency.arb's "tryAgain" key is reused here so contacts_page.dart
  // doesn't need its own duplicate key for the same word.
  String tryAgainLabelFallback(BuildContext context) => tryAgain;
}

class _ShareDurationDialog extends StatelessWidget {
  const _ShareDurationDialog();

  Widget _option(BuildContext context, String label, int value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.timer_outlined, size: 20, color: Color(0xFF667EEA)),
      title: Text(label),
      onTap: () => Navigator.pop(context, value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Share my live location'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'People who added you as an emergency contact will see where you are on their map while the app is open. You can stop at any time.',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 12),
          _option(context, 'For 1 hour', 60),
          _option(context, 'For 8 hours', 480),
          _option(context, 'Until I turn it off', 0),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback onCall;
  final VoidCallback onInvite;
  final VoidCallback onDelete;

  const _ContactCard({required this.contact, required this.onCall, required this.onInvite, required this.onDelete});

  String get _initials => _initialsOf(contact['name'] as String? ?? '?');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hasApp = contact['has_app'] == true;
    final status = contact['status']?.toString() ?? 'accepted';

    // What to show for this person.
    final String label;
    final IconData icon;
    final Color bg;
    final Color fg;
    if (hasApp && status == 'accepted') {
      label = l.protectedLabel;
      icon = Icons.verified_rounded;
      bg = const Color(0xFFE6F7EC);
      fg = const Color(0xFF28A745);
    } else if (hasApp && status == 'pending') {
      label = 'Request sent';
      icon = Icons.send_rounded;
      bg = const Color(0xFFE8F0FE);
      fg = const Color(0xFF1A3D7C);
    } else if (hasApp && status == 'declined') {
      label = 'Declined';
      icon = Icons.block_rounded;
      bg = const Color(0xFFF0F2F5);
      fg = const Color(0xFF6C757D);
    } else {
      label = l.invitePending;
      icon = Icons.hourglass_top_rounded;
      bg = const Color(0xFFFFF3CD);
      fg = const Color(0xFF856404);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)])),
                child: Center(child: Text(_initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(8)),
                          child: Text(contact['relationship'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFF555555), fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        Text(contact['phone_number'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFDC3545))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: fg),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onCall,
                icon: const Icon(Icons.call_rounded, size: 19, color: Color(0xFF28A745)),
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: EdgeInsets.zero,
              ),
              if (!hasApp)
                TextButton.icon(
                  onPressed: onInvite,
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF667EEA), padding: const EdgeInsets.symmetric(horizontal: 10)),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(l.sendInvite, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelationshipDialog extends StatefulWidget {
  final String name;
  const _RelationshipDialog({required this.name});

  @override
  State<_RelationshipDialog> createState() => _RelationshipDialogState();
}

class _RelationshipDialogState extends State<_RelationshipDialog> {
  String _selected = _relationshipKeys.first;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(l.addPersonTitle(widget.name)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.howDoYouKnowThisPerson, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selected,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            items: _relationshipKeys.map((key) => DropdownMenuItem(value: key, child: Text(_relationshipLabel(context, key)))).toList(),
            onChanged: (v) => setState(() => _selected = v!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667EEA)),
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(l.add, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _ContactPickerSheet extends StatefulWidget {
  final List<Contact> contacts;
  const _ContactPickerSheet({required this.contacts});

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  String _query = '';

  List<Contact> get _filtered {
    if (_query.isEmpty) return widget.contacts;
    final q = _query.toLowerCase();
    return widget.contacts.where((c) => c.displayName.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(child: Text(l.chooseAContact, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: l.searchContacts,
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text(l.noContactsFound, style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final c = _filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF667EEA),
                          child: Text(
                            c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(c.displayName),
                        subtitle: Text(c.phones.first.number),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}