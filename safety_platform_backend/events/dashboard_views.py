from functools import wraps

from django.contrib import messages
from django.contrib.auth.views import redirect_to_login
from django.db.models import Case, Count, IntegerField, Max, Q, When
from django.http import HttpResponseForbidden, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.http import require_POST

from .models import OPEN_STATUSES, Event, EventAttendance, EventIncident


def _is_admin(user):
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


def admin_required(view):
    @wraps(view)
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            return redirect_to_login(request.get_full_path())
        if not _is_admin(request.user):
            return HttpResponseForbidden("You do not have access to the dashboard.")
        return view(request, *args, **kwargs)

    return wrapper


@admin_required
def event_list(request):
    now = timezone.now()
    events = Event.objects.select_related("host").annotate(
        attendee_total=Count("attendances", distinct=True),
        open_total=Count("incidents", filter=Q(incidents__status__in=OPEN_STATUSES), distinct=True),
    )

    status = request.GET.get("status", "").strip()
    q = request.GET.get("q", "").strip()
    if status in dict(Event.STATUS_CHOICES):
        events = events.filter(status=status)
    if q:
        events = events.filter(
            Q(title__icontains=q)
            | Q(venue_name__icontains=q)
            | Q(host__full_name__icontains=q)
            | Q(host__email__icontains=q)
        )

    open_alerts = EventIncident.objects.filter(status__in=OPEN_STATUSES)
    context = {
        "events": list(events.order_by("-start_at")[:200]),
        "status": status,
        "q": q,
        "status_choices": Event.STATUS_CHOICES,
        "total_events": Event.objects.count(),
        "live_events": Event.objects.filter(status="published", start_at__lte=now, end_at__gte=now).count(),
        "upcoming_events": Event.objects.filter(status="published", start_at__gt=now).count(),
        "open_incidents": open_alerts.count(),
        "critical_open": open_alerts.filter(severity="critical").count(),
    }
    return render(request, "dashboard/events/event_list.html", context)


@admin_required
def event_detail(request, pk):
    event = get_object_or_404(Event.objects.select_related("host"), pk=pk)
    context = {
        "event": event,
        "incidents": list(event.incidents.select_related("reporter")[:200]),
        "attendee_total": event.attendances.count(),
        "attendees": EventAttendance.objects.filter(event=event).select_related("user")[:30],
        "open_total": event.open_incident_count,
    }
    return render(request, "dashboard/events/event_detail.html", context)


@admin_required
@require_POST
def event_visibility(request, pk):
    event = get_object_or_404(Event, pk=pk)
    action = request.POST.get("action")
    if action == "hide":
        event.status = "hidden"
        event.save()
        messages.success(request, "Event hidden from the public list.")
    elif action == "unhide" and event.status == "hidden":
        event.status = "published"
        event.save()
        messages.success(request, "Event is public again.")
    return redirect("events_admin:detail", pk=pk)


@admin_required
def incident_list(request):
    state = request.GET.get("state", "open")
    severity = request.GET.get("severity", "")
    event_id = request.GET.get("event", "")

    incidents = EventIncident.objects.select_related("event", "reporter")
    if state == "open":
        incidents = incidents.filter(status__in=OPEN_STATUSES)
    elif state == "closed":
        incidents = incidents.filter(status__in=["resolved", "false_alarm"])
    if severity in dict(EventIncident.SEVERITY_CHOICES):
        incidents = incidents.filter(severity=severity)
    if event_id.isdigit():
        incidents = incidents.filter(event_id=int(event_id))

    rank = Case(
        When(severity="critical", then=0),
        When(severity="high", then=1),
        When(severity="medium", then=2),
        default=3,
        output_field=IntegerField(),
    )
    incidents = incidents.annotate(rank=rank).order_by("rank", "-created_at")

    open_alerts = EventIncident.objects.filter(status__in=OPEN_STATUSES)
    context = {
        "incidents": list(incidents[:300]),
        "state": state,
        "severity": severity,
        "event_id": event_id,
        "events": Event.objects.order_by("-start_at")[:100],
        "severity_choices": EventIncident.SEVERITY_CHOICES,
        "open_total": open_alerts.count(),
        "new_total": open_alerts.filter(status="new").count(),
        "critical_total": open_alerts.filter(severity="critical").count(),
        "closed_today": EventIncident.objects.filter(
            status__in=["resolved", "false_alarm"], resolved_at__date=timezone.localdate()
        ).count(),
    }
    return render(request, "dashboard/events/incident_list.html", context)


@admin_required
def incident_detail(request, pk):
    incident = get_object_or_404(
        EventIncident.objects.select_related("event", "event__host", "reporter", "handled_by"), pk=pk
    )

    if request.method == "POST":
        new_status = request.POST.get("status", "")
        notes = request.POST.get("notes", "").strip()
        if new_status in dict(EventIncident.STATUS_CHOICES) and new_status != "new":
            incident.set_status(new_status, request.user, notes)
            messages.success(request, f"{incident.reference} marked as {incident.get_status_display().lower()}.")
        elif notes:
            incident.add_note(notes)
            incident.save()
            messages.success(request, "Note added.")
        return redirect("events_admin:incident_detail", pk=pk)

    return render(
        request,
        "dashboard/events/incident_detail.html",
        {"incident": incident, "status_choices": EventIncident.STATUS_CHOICES},
    )


def pending_json(request):
    """Polled by the dashboard every 10 seconds to drive the badge and toasts."""
    if not _is_admin(request.user):
        return JsonResponse({"detail": "forbidden"}, status=403)

    open_alerts = EventIncident.objects.filter(status__in=OPEN_STATUSES)
    latest = []
    for i in open_alerts.select_related("event").order_by("-id")[:8]:
        latest.append(
            {
                "id": i.id,
                "reference": i.reference,
                "kind": i.get_kind_display(),
                "severity": i.severity,
                "event": i.event.title,
                "location": i.location_description,
                "anonymous": i.is_anonymous,
                "url": reverse("events_admin:incident_detail", args=[i.id]),
                "created_at": i.created_at.isoformat(),
            }
        )
    return JsonResponse(
        {
            "open_count": open_alerts.count(),
            "new_count": open_alerts.filter(status="new").count(),
            "critical_count": open_alerts.filter(severity="critical").count(),
            "latest_id": EventIncident.objects.aggregate(m=Max("id"))["m"] or 0,
            "latest": latest,
        }
    )