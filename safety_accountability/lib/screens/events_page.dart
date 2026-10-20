import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/location_field.dart';
import '../services/events_service.dart';
import 'event_detail_page.dart';
import 'events_common.dart';

/// The page opened from the hamburger menu: host an event or attend one.
class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF667EEA).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: const Row(
              children: [
                Icon(Icons.event_rounded, color: Colors.white, size: 40),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Events', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 3),
                      Text('Host an event, or join one and help keep it safe',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _OptionCard(
            icon: Icons.add_business_rounded,
            color: const Color(0xFF764BA2),
            title: 'Host an event',
            subtitle: 'Fill in the details and post it for the public to see. You and the platform security team receive the safety alerts from your guests.',
            onTap: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const HostEventPage()),
              );
              if (created == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your event is live. People can now find it under Attend an event.')),
                );
              }
            },
          ),
          const SizedBox(height: 14),
          _OptionCard(
            icon: Icons.confirmation_number_rounded,
            color: const Color(0xFF667EEA),
            title: 'Attend an event',
            subtitle: 'Browse events posted by hosts. Once you join, you get safety tools: report anonymously, trigger an SOS and send other alerts.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendEventsPage())),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HostedEventsPage())),
            icon: const Icon(Icons.shield_rounded),
            label: const Text('My hosted events and safety alerts'),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Colors.grey, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Attend: list of public events
// ======================================================================

class AttendEventsPage extends StatefulWidget {
  const AttendEventsPage({super.key});

  @override
  State<AttendEventsPage> createState() => _AttendEventsPageState();
}

class _AttendEventsPageState extends State<AttendEventsPage> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await EventsService.listEvents();
      if (!mounted) return;
      setState(() => _events = list);
    } on EventsException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _events;
    return _events.where((e) {
      final hay = '${e['title']} ${e['venue_name']} ${e['address']}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _open(Map<String, dynamic> event) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailPage(event: event)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Attend an event'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search events, venues or areas',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
                  : _error != null
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                            TextButton(onPressed: _load, child: const Text('Try again')),
                          ],
                        )
                      : items.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(40),
                              children: const [
                                Icon(Icons.event_busy_rounded, size: 46, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No upcoming events', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                SizedBox(height: 6),
                                Text('Events posted by hosts will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, i) => EventCard(event: items[i], onTap: () => _open(items[i])),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Host: events I created + alerts
// ======================================================================

class HostedEventsPage extends StatefulWidget {
  const HostedEventsPage({super.key});

  @override
  State<HostedEventsPage> createState() => _HostedEventsPageState();
}

class _HostedEventsPageState extends State<HostedEventsPage> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await EventsService.hostedEvents();
      if (!mounted) return;
      setState(() => _events = list);
    } on EventsException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> event) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailPage(event: event)));
    if (mounted) _load();
  }

  Future<void> _host() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const HostEventPage()));
    if (created == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My hosted events'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _host,
        backgroundColor: const Color(0xFF764BA2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Host an event'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(32),
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      TextButton(onPressed: _load, child: const Text('Try again')),
                    ],
                  )
                : _events.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(40),
                        children: const [
                          Icon(Icons.event_note_rounded, size: 46, color: Colors.grey),
                          SizedBox(height: 12),
                          Text("You haven't hosted an event yet", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          SizedBox(height: 6),
                          Text('Tap Host an event to post one. Safety alerts from your guests show up here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        itemCount: _events.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => EventCard(event: _events[i], onTap: () => _open(_events[i])),
                      ),
      ),
    );
  }
}

// ======================================================================
// Host: create an event
// ======================================================================

class HostEventPage extends StatefulWidget {
  const HostEventPage({super.key});

  @override
  State<HostEventPage> createState() => _HostEventPageState();
}

class _HostEventPageState extends State<HostEventPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _address = TextEditingController();
  final _attendance = TextEditingController();
  final _hostPhone = TextEditingController();
  final _securityName = TextEditingController();
  final _securityPhone = TextEditingController();

  String _category = 'community';
  DateTime? _start;
  DateTime? _end;
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _venue.dispose();
    _address.dispose();
    _attendance.dispose();
    _hostPhone.dispose();
    _securityName.dispose();
    _securityPhone.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var initialDate = initial ?? now;
    if (initialDate.isBefore(today)) initialDate = today;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _chooseStart() async {
    final picked = await _pickDateTime(_start);
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_end == null || !_end!.isAfter(picked)) _end = picked.add(const Duration(hours: 3));
    });
  }

  Future<void> _chooseEnd() async {
    final picked = await _pickDateTime(_end ?? _start);
    if (picked == null) return;
    setState(() => _end = picked);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast("Turn on your phone's location services first.");
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _toast('Location permission is needed to pin the venue.');
        return;
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        _toast('Could not get your location. Try again.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _lat = double.parse(pos!.latitude.toStringAsFixed(6));
        _lng = double.parse(pos.longitude.toStringAsFixed(6));
      });
    } catch (_) {
      _toast('Could not get your location. Try again.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    String? problem;
    if (_title.text.trim().isEmpty) {
      problem = 'Give your event a name.';
    } else if (_description.text.trim().isEmpty) {
      problem = 'Describe your event.';
    } else if (_venue.text.trim().isEmpty) {
      problem = 'Enter the venue name.';
    } else if (_start == null || _end == null) {
      problem = 'Choose when the event starts and ends.';
    } else if (!_end!.isAfter(_start!)) {
      problem = 'The event must end after it starts.';
    } else if (_hostPhone.text.trim().isEmpty) {
      problem = 'Enter a phone number guests and security can reach you on.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final attendance = int.tryParse(_attendance.text.trim());
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await EventsService.createEvent({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'venue_name': _venue.text.trim(),
        'address': _address.text.trim(),
        'start_at': _start!.toUtc().toIso8601String(),
        'end_at': _end!.toUtc().toIso8601String(),
        'host_phone': _hostPhone.text.trim(),
        'security_head_name': _securityName.text.trim(),
        'security_head_phone': _securityPhone.text.trim(),
        'expected_attendance': ?attendance,
        if (_lat != null && _lng != null) 'latitude': _lat,
        if (_lat != null && _lng != null) 'longitude': _lng,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on EventsException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Host an event'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_rounded, color: Color(0xFF007BFF), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your event will be public. People who join can send safety alerts and anonymous reports. You see them under My hosted events, and the platform security team sees them too.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF1A3D7C), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(controller: _title, textCapitalization: TextCapitalization.sentences, decoration: _dec('Event name *', icon: Icons.title_rounded)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: _dec('Type of event', icon: Icons.category_rounded),
                items: eventCategories.map((c) => DropdownMenuItem(value: c.value, child: Text(c.label))).toList(),
                onChanged: (v) => setState(() => _category = v ?? 'community'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _description,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('What is the event about? *', hint: 'Programme, rules, what to bring...'),
              ),
              const SizedBox(height: 14),
              TextField(controller: _venue, decoration: _dec('Venue name *', icon: Icons.place_rounded)),
              const SizedBox(height: 14),
                            LocationField(
                controller: _address,
                label: 'Address or area',
                hint: 'Search the venue address',
                icon: Icons.map_rounded,
                onSelected: (place) => setState(() {
                  _lat = place.latitude;
                  _lng = place.longitude;
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _useMyLocation,
                    icon: _locating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Pin venue at my location'),
                  ),
                  const SizedBox(width: 10),
                  if (_lat != null)
                    const Expanded(child: Text('Pinned', style: TextStyle(color: Color(0xFF28A745), fontWeight: FontWeight.w600))),
                ],
              ),
              const SizedBox(height: 14),
              _DateTile(label: 'Starts *', value: formatPickedDateTime(_start), onTap: _chooseStart),
              const SizedBox(height: 10),
              _DateTile(label: 'Ends *', value: formatPickedDateTime(_end), onTap: _chooseEnd),
              const SizedBox(height: 14),
              TextField(
                controller: _attendance,
                keyboardType: TextInputType.number,
                decoration: _dec('Expected number of guests', icon: Icons.people_alt_rounded),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _hostPhone,
                keyboardType: TextInputType.phone,
                decoration: _dec('Your contact number *', icon: Icons.phone_rounded),
              ),
              const SizedBox(height: 14),
              TextField(controller: _securityName, decoration: _dec('Head of security (name)', icon: Icons.shield_rounded)),
              const SizedBox(height: 14),
              TextField(
                controller: _securityPhone,
                keyboardType: TextInputType.phone,
                decoration: _dec('Head of security (phone)', icon: Icons.phone_in_talk_rounded),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFDC3545))),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF764BA2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.public_rounded, color: Colors.white),
                  label: Text(_submitting ? 'Posting...' : 'Post event for the public',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_rounded, size: 20, color: Color(0xFF667EEA)),
          ],
        ),
      ),
    );
  }
}