import logging
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db.models import Q
from django.http import JsonResponse
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.cache import never_cache

from activity_log.models import ADMIN_OPEN_STATUSES, LoggedActivity
from community.models import CommunityPost, PostReport
from ehailing.models import EhailingPanicAlert, PassengerLog, Trip
from emergencies.models import EmergencyReport
from events.models import OPEN_STATUSES as EVENT_OPEN_STATUSES
from events.models import Event, EventIncident
from reports.models import AnonymousReport

logger = logging.getLogger(__name__)
User = get_user_model()

ITEM_LIMIT = 8


def _is_admin(user):
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


def _who(user, fallback="Someone"):
    if not user:
        return fallback
    return user.full_name or user.email


def _short(text, n=80):
    text = (text or "").strip().replace("\n", " ")
    return text if len(text) <= n else text[: n - 1] + "…"


def _item(key, severity, title, line, meta, url):
    return {"key": key, "severity": severity, "title": title, "line": line, "meta": meta, "url": url}


# Each builder returns (count, urgent_count, items).


def _accounts(now):
    people = User.objects.filter(is_dashboard_admin=False, is_superuser=False).order_by("-id")[:5]
    items = [
        _item(f"user-{u.id}", "low", "New account", _who(u), u.email, reverse("dashboard:account_detail", args=[u.id]))
        for u in people
    ]
    return 0, 0, items


def _reports(now):
    open_qs = AnonymousReport.objects.filter(status__in=["submitted", "under_investigation"])
    urgent = open_qs.filter(Q(urgency="critical") | Q(requires_immediate_action=True)).count()
    items = []
    for r in open_qs.filter(status="submitted").order_by("-id")[:ITEM_LIMIT]:
        if r.urgency == "critical" or r.requires_immediate_action:
            severity = "critical"
        elif r.urgency == "high":
            severity = "high"
        elif r.urgency == "medium":
            severity = "medium"
        else:
            severity = "low"
        items.append(
            _item(
                f"report-{r.id}",
                severity,
                f"New anonymous report: {r.get_category_display()}",
                r.location or "No location given",
                r.tracking_code,
                reverse("dashboard:report_detail", args=[r.id]),
            )
        )
    return open_qs.count(), urgent, items


def _emergencies(now):
    open_qs = EmergencyReport.objects.filter(status__in=["active", "responding"]).select_related("user")
    open_list = list(open_qs.order_by("-id")[:100])
    overdue = [e for e in open_list if e.is_overdue]
    items = []
    for e in open_list[:ITEM_LIMIT]:
        url = reverse("dashboard:emergency_detail", args=[e.id])
        line = f"{_who(e.user)} · {e.location_description or 'Location in details'}"
        items.append(_item(f"emergency-{e.id}", "critical", f"EMERGENCY: {e.get_incident_type_display()}", line, e.reference, url))
        if e.is_overdue:
            items.append(
                _item(f"emergency-{e.id}-overdue", "critical", "OVERDUE, no response yet", line, e.reference, url)
            )
    return open_qs.count(), len(overdue), items


def _activity(now):
    """
    Activity logs are private to the person and their emergency contacts.
    They only reach the admin team once a contact escalates one because
    the person did not return, so only escalated cases are counted here.
    """
    open_qs = LoggedActivity.objects.filter(
        escalated_at__isnull=False, admin_status__in=ADMIN_OPEN_STATUSES
    ).select_related("user", "escalated_by")
    new_qs = open_qs.filter(admin_status="new")
    items = [
        _item(
            f"activity-{a.id}-escalated",
            "critical",
            f"Person did not return: {a.get_activity_type_display()}",
            f"{_who(a.user)} · {a.location}",
            f"Escalated by {_who(a.escalated_by)}",
            reverse("dashboard:activity_detail", args=[a.id]),
        )
        for a in new_qs.order_by("-escalated_at")[:ITEM_LIMIT]
    ]
    return open_qs.count(), new_qs.count(), items


def _community(now):
    open_reports = PostReport.objects.filter(resolved=False).select_related("post", "reporter")
    items = [
        _item(
            f"postreport-{r.id}",
            "medium",
            f"Post reported: {r.get_reason_display()}",
            _short(r.post.content),
            f"Reported by {_who(r.reporter)}",
            reverse("dashboard:post_detail", args=[r.post_id]),
        )
        for r in open_reports.order_by("-id")[:ITEM_LIMIT]
    ]
    quick = CommunityPost.objects.filter(
        is_quick_alert=True, status="published", created_at__gte=now - timedelta(hours=2)
    ).select_related("author")
    for p in quick.order_by("-id")[:ITEM_LIMIT]:
        items.append(
            _item(
                f"quickalert-{p.id}",
                "high",
                "Quick alert posted",
                _short(p.content),
                _who(p.author),
                reverse("dashboard:post_detail", args=[p.id]),
            )
        )
    return open_reports.count(), 0, items


def _events(now):
    new_events = Event.objects.filter(status="published").select_related("host").order_by("-id")[:5]
    items = [
        _item(
            f"event-{e.id}",
            "low",
            "New event posted",
            e.title,
            f"{e.venue_name} · {_who(e.host, 'Unknown host')}",
            reverse("events_admin:detail", args=[e.id]),
        )
        for e in new_events
    ]
    return 0, 0, items


def _event_alerts(now):
    open_qs = EventIncident.objects.filter(status__in=EVENT_OPEN_STATUSES).select_related("event")
    urgent = open_qs.filter(severity="critical").count()
    items = [
        _item(
            f"eventincident-{i.id}",
            i.severity,
            i.get_kind_display(),
            f"{i.event.title}" + (f" · {i.location_description}" if i.location_description else ""),
            ("Anonymous report" if i.is_anonymous else "Alert") + f" · {i.reference}",
            reverse("events_admin:incident_detail", args=[i.id]),
        )
        for i in open_qs.filter(status="new").order_by("-id")[:ITEM_LIMIT]
    ]
    return open_qs.count(), urgent, items


def _panic(now):
    open_qs = EhailingPanicAlert.objects.filter(status__in=["active", "responding"]).select_related("user")
    open_list = list(open_qs.order_by("-id")[:100])
    overdue = [p for p in open_list if p.is_overdue]
    items = []
    for p in open_list[:ITEM_LIMIT]:
        url = reverse("dashboard:ehailing_panic_detail", args=[p.id])
        line = f"{_who(p.user)} ({p.get_role_display()})"
        items.append(_item(f"panic-{p.id}", "critical", "E-HAILING PANIC", line, "Needs a response now", url))
        if p.is_overdue:
            items.append(_item(f"panic-{p.id}-overdue", "critical", "PANIC OVERDUE, no response yet", line, "", url))
    return open_qs.count(), len(overdue), items


def _trips(now):
    return Trip.objects.filter(status="active").count(), 0, []


def _passenger_logs(now):
    return PassengerLog.objects.filter(status="active").count(), 0, []


# key, label, icon, tone ("alert" counts toward the tab total, "info" does not), builder
SECTION_BUILDERS = [
    ("accounts", "Accounts", "bi-people", "info", _accounts),
    ("reports", "Anonymous Reports", "bi-flag", "alert", _reports),
    ("emergencies", "Emergencies", "bi-exclamation-triangle", "alert", _emergencies),
    ("activity", "Activity Log", "bi-journal-text", "alert", _activity),
    ("community", "Community", "bi-chat-dots", "alert", _community),
    ("events", "Events", "bi-calendar-event", "info", _events),
    ("event_alerts", "Event Alerts", "bi-bell", "alert", _event_alerts),
    ("panic", "Panic Alerts", "bi-exclamation-octagon", "alert", _panic),
    ("trips", "Trips", "bi-car-front", "info", _trips),
    ("passenger_logs", "Passenger Logs", "bi-person-badge", "info", _passenger_logs),
]


@never_cache
def pending(request):
    """Polled by every dashboard page to drive sidebar badges, toasts and sound."""
    if not _is_admin(request.user):
        return JsonResponse({"detail": "forbidden"}, status=403)

    now = timezone.now()
    sections = {}
    total = 0
    for key, label, icon, tone, builder in SECTION_BUILDERS:
        try:
            count, urgent, items = builder(now)
        except Exception:
            logger.exception("Live dashboard section '%s' failed", key)
            count, urgent, items = 0, 0, []
        sections[key] = {"label": label, "icon": icon, "tone": tone, "count": count, "urgent": urgent, "items": items}
        if tone == "alert":
            total += count
    return JsonResponse({"sections": sections, "total": total})