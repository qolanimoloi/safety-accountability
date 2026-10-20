import 'package:flutter/material.dart';

class EventCategory {
  final String value;
  final String label;
  final IconData icon;
  const EventCategory(this.value, this.label, this.icon);
}

const List<EventCategory> eventCategories = [
  EventCategory('music', 'Music / Concert', Icons.music_note_rounded),
  EventCategory('sports', 'Sports', Icons.sports_soccer_rounded),
  EventCategory('community', 'Community gathering', Icons.groups_rounded),
  EventCategory('religious', 'Religious', Icons.volunteer_activism_rounded),
  EventCategory('festival', 'Festival / Market', Icons.celebration_rounded),
  EventCategory('political', 'Rally / Political', Icons.campaign_rounded),
  EventCategory('school', 'School / Campus', Icons.school_rounded),
  EventCategory('other', 'Other', Icons.event_rounded),
];

EventCategory eventCategoryOf(String? value) =>
    eventCategories.firstWhere((c) => c.value == value, orElse: () => eventCategories.last);

class IncidentKind {
  final String value;
  final String label;
  final String shortLabel;
  final IconData icon;
  const IncidentKind(this.value, this.label, this.shortLabel, this.icon);
}

const List<IncidentKind> incidentKinds = [
  IncidentKind('panic', 'SOS - I need help now', 'SOS', Icons.warning_rounded),
  IncidentKind('medical', 'Medical emergency', 'Medical', Icons.medical_services_rounded),
  IncidentKind('fire', 'Fire / smoke', 'Fire', Icons.local_fire_department_rounded),
  IncidentKind('violence', 'Fight / violence', 'Fight', Icons.personal_injury_rounded),
  IncidentKind('harassment', 'Harassment / GBV', 'Harassment', Icons.report_problem_rounded),
  IncidentKind('theft', 'Theft / robbery', 'Theft', Icons.money_off_rounded),
  IncidentKind('suspicious', 'Suspicious person or item', 'Suspicious', Icons.visibility_rounded),
  IncidentKind('lost_child', 'Lost child / missing person', 'Lost child', Icons.child_care_rounded),
  IncidentKind('crowd', 'Overcrowding / crowd crush', 'Crowding', Icons.groups_rounded),
  IncidentKind('drugs', 'Drug activity', 'Drugs', Icons.medication_rounded),
  IncidentKind('other', 'Other', 'Other', Icons.more_horiz_rounded),
];

IncidentKind incidentKindOf(String? value) =>
    incidentKinds.firstWhere((k) => k.value == value, orElse: () => incidentKinds.last);

const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

DateTime? parseDate(dynamic value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal();

String formatEventWhen(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '';
  final day = '${_weekdays[start.weekday - 1]} ${start.day} ${_months[start.month - 1]}';
  final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
  if (sameDay) {
    return '$day · ${_two(start.hour)}:${_two(start.minute)} – ${_two(end.hour)}:${_two(end.minute)}';
  }
  return '$day ${_two(start.hour)}:${_two(start.minute)} → ${end.day} ${_months[end.month - 1]} ${_two(end.hour)}:${_two(end.minute)}';
}

String formatPickedDateTime(DateTime? d) {
  if (d == null) return 'Tap to choose';
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}, ${_two(d.hour)}:${_two(d.minute)}';
}

String agoLabel(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

Color severityColor(String? severity) {
  switch (severity) {
    case 'critical':
      return const Color(0xFFDC3545);
    case 'high':
      return const Color(0xFFFD7E14);
    case 'medium':
      return const Color(0xFF0DA2C4);
    default:
      return Colors.grey;
  }
}

Color incidentStatusColor(String? status) {
  switch (status) {
    case 'new':
      return const Color(0xFFDC3545);
    case 'acknowledged':
      return const Color(0xFFB38F00);
    case 'responding':
      return const Color(0xFF667EEA);
    case 'resolved':
      return const Color(0xFF28A745);
    default:
      return Colors.grey;
  }
}

class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const EventCard({super.key, required this.event, required this.onTap});

  Widget _chip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = eventCategoryOf(event['category']?.toString());
    final start = parseDate(event['start_at']);
    final end = parseDate(event['end_at']);
    final attending = event['attending'] == true;
    final isHost = event['is_host'] == true;
    final status = event['status']?.toString();
    final open = (event['open_incidents'] as num?)?.toInt() ?? 0;
    final count = (event['attendee_count'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
              ),
              child: Icon(cat.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(formatEventWhen(start, end), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    event['venue_name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip('$count attending', const Color(0xFF667EEA), icon: Icons.people_alt_rounded),
                      if (isHost) _chip('Hosting', const Color(0xFF764BA2)),
                      if (attending && !isHost) _chip('Attending', const Color(0xFF28A745), icon: Icons.check_circle_rounded),
                      if (status == 'cancelled') _chip('Cancelled', Colors.grey),
                      if (status == 'hidden') _chip('Hidden by admin', Colors.grey),
                      if (open > 0) _chip('$open open alert${open == 1 ? '' : 's'}', const Color(0xFFDC3545), icon: Icons.notifications_active_rounded),
                    ],
                  ),
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