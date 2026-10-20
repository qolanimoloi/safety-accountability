from django.core.cache import cache
from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from .models import Event, EventAttendance, EventIncident, IncidentEvidence
from .serializers import (
    EventCreateSerializer,
    EventSerializer,
    IncidentCreateSerializer,
    IncidentSerializer,
    validate_evidence_files,
)

MAX_ALERTS_PER_10_MIN = 8


def _event_data(event, request):
    return EventSerializer(event, context={"request": request}).data


def _is_staff(user):
    return bool(user.is_dashboard_admin or user.is_superuser)


def _can_manage(user, event):
    return event.host_id == user.id or _is_staff(user)


def _is_participant(user, event):
    return event.host_id == user.id or event.attendances.filter(user=user).exists()


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def event_list_create(request):
    if request.method == "GET":
        events = Event.objects.filter(status="published", end_at__gte=timezone.now()).select_related("host")
        q = request.query_params.get("q", "").strip()
        if q:
            events = events.filter(
                Q(title__icontains=q) | Q(venue_name__icontains=q) | Q(address__icontains=q)
            )
        return Response(EventSerializer(events.order_by("start_at"), many=True, context={"request": request}).data)

    serializer = EventCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    event = serializer.save(host=request.user)
    return Response(_event_data(event, request), status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def hosting_list(request):
    events = Event.objects.filter(host=request.user).order_by("-start_at")
    return Response(EventSerializer(events, many=True, context={"request": request}).data)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def event_detail(request, pk):
    event = get_object_or_404(Event, pk=pk)
    if event.status == "hidden" and not _can_manage(request.user, event):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
    return Response(_event_data(event, request))


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def event_cancel(request, pk):
    event = get_object_or_404(Event, pk=pk, host=request.user)
    if event.status == "published":
        event.status = "cancelled"
        event.save()
    return Response(_event_data(event, request))


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def event_attend(request, pk):
    event = get_object_or_404(Event, pk=pk, status="published")
    if event.has_ended:
        return Response({"detail": "This event has already ended."}, status=status.HTTP_400_BAD_REQUEST)
    EventAttendance.objects.get_or_create(event=event, user=request.user)
    return Response(_event_data(event, request))


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def event_leave(request, pk):
    event = get_object_or_404(Event, pk=pk)
    EventAttendance.objects.filter(event=event, user=request.user).delete()
    return Response(_event_data(event, request))


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def incident_list_create(request, pk):
    event = get_object_or_404(Event, pk=pk)
    user = request.user

    if request.method == "GET":
        # Only the host (head of security) or a dashboard admin can read alerts.
        if not _can_manage(user, event):
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        incidents = event.incidents.select_related("reporter").prefetch_related("evidence")
        return Response(IncidentSerializer(incidents, many=True, context={"request": request}).data)

    if not event.accepts_alerts:
        return Response({"detail": "Safety alerts are closed for this event."}, status=status.HTTP_400_BAD_REQUEST)
    if not _is_participant(user, event):
        return Response({"detail": "Join this event first to send safety alerts."}, status=status.HTTP_403_FORBIDDEN)

    # Simple per-user limit (kept in the cache only, nothing stored in the
    # database, so anonymous reports are still not linked to anyone).
    key = f"event-incident-rate:{user.id}"
    cache.add(key, 0, 600)
    try:
        count = cache.incr(key)
    except ValueError:
        cache.set(key, 1, 600)
        count = 1
    if count > MAX_ALERTS_PER_10_MIN:
        return Response(
            {"detail": "Too many alerts sent. Please wait a few minutes."},
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    serializer = IncidentCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data

    files = request.FILES.getlist("evidence")
    validate_evidence_files(files)

    anonymous = bool(data.get("is_anonymous"))
    severity = EventIncident.DEFAULT_SEVERITY.get(data["kind"], "medium")
    if data.get("needs_immediate_help"):
        severity = "critical"

    with transaction.atomic():
        incident = EventIncident.objects.create(
            event=event,
            reporter=None if anonymous else user,
            is_anonymous=anonymous,
            kind=data["kind"],
            severity=severity,
            description=data.get("description", "").strip(),
            location_description=data.get("location_description", "").strip(),
            latitude=data.get("latitude"),
            longitude=data.get("longitude"),
        )
        for f in files:
            IncidentEvidence.objects.create(
                incident=incident,
                file=f,
                # An anonymous sender's file name is not kept.
                original_filename="" if anonymous else f.name[:255],
                content_type=(getattr(f, "content_type", "") or "")[:100],
                size_bytes=f.size,
            )

    return Response(
        {
            "reference": incident.reference,
            "status": incident.status,
            "severity": incident.severity,
            "is_anonymous": anonymous,
            "evidence_count": len(files),
            "message": (
                "Your anonymous report was sent to the event's security team."
                if anonymous
                else "Your alert was sent to the event's security team."
            ),
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def incident_set_status(request, pk):
    incident = get_object_or_404(EventIncident.objects.select_related("event"), pk=pk)
    if not _can_manage(request.user, incident.event):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    new_status = request.data.get("status")
    if new_status not in dict(EventIncident.STATUS_CHOICES) or new_status == "new":
        return Response({"status": ["Choose a valid status."]}, status=status.HTTP_400_BAD_REQUEST)

    incident.set_status(new_status, request.user, request.data.get("notes", ""))
    return Response(IncidentSerializer(incident, context={"request": request}).data)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def incident_track(request, reference):
    incident = get_object_or_404(EventIncident.objects.select_related("event"), reference=reference)
    if not (_is_participant(request.user, incident.event) or _is_staff(request.user)):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
    return Response(
        {
            "reference": incident.reference,
            "kind_display": incident.get_kind_display(),
            "status": incident.status,
            "status_display": incident.get_status_display(),
            "created_at": incident.created_at,
        }
    )