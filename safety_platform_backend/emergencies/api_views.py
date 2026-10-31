import logging

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .models import EmergencyContact, EmergencyReport
from .notify import mark_handled, send_notification
from .serializers import (
    ContactRequestSerializer,
    EmergencyContactCreateSerializer,
    EmergencyContactSerializer,
    EmergencyStatusSerializer,
    EmergencyTriggerSerializer,
    IncomingAlertSerializer,
)

logger = logging.getLogger(__name__)


def _who(user):
    return user.full_name or user.email


def _safely(func, *args, **kwargs):
    """
    Notifications are a courtesy. If one fails it must never turn a
    request that already worked into an error 500 for the person.
    """
    try:
        func(*args, **kwargs)
    except Exception:
        logger.exception("Contact notification failed")


def _notify_request(contact, sender):
    """Tell the other person (if they have the app) that a request is waiting."""
    person = contact.linked_user
    if person:
        _safely(
            send_notification,
            person,
            "alert",
            f"{_who(sender)} wants to add you as an emergency contact. Tap to accept or decline.",
            action="contact_request",
            object_id=contact.id,
        )


def _ensure_reverse_contact(accepter, requester):
    """
    Two-way contacts. When `accepter` accepts a request from `requester`,
    `requester` must also be in `accepter`'s circle (already accepted), so
    nobody has to send a second request.
    Returns the contact row, or None if the requester has no phone number saved
    (a contact is matched by phone number, so there is nothing to save).
    """
    phone = requester.phone_number
    norm = EmergencyContact._normalize(phone)
    if not phone or not norm:
        return None

    now = timezone.now()
    for existing in accepter.emergency_contacts.all():
        if EmergencyContact._normalize(existing.phone_number) == norm:
            if existing.status != "accepted":
                existing.status = "accepted"
                existing.responded_at = now
                existing.save(update_fields=["status", "responded_at"])
            return existing

    return EmergencyContact.objects.create(
        owner=accepter,
        name=_who(requester)[:150],
        phone_number=phone,
        relationship="Friend",
        status="accepted",
        responded_at=now,
    )


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])  # emergency_page.dart only reachable once logged in
def trigger_emergency(request):
    serializer = EmergencyTriggerSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    emergency = serializer.save(user=request.user)

    # Alert every ACCEPTED emergency contact of this user who is also a
    # registered account on the platform, alongside the admin dashboard.
    # Pending and declined contacts are not alerted.
    linked_contacts = [
        c.linked_user for c in request.user.emergency_contacts.filter(status="accepted") if c.linked_user
    ]
    if linked_contacts:
        emergency.notified_contacts.set(linked_contacts)

    return Response(EmergencyStatusSerializer(emergency).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def emergency_status(request, reference):
    # Only the reporter (or staff) can poll this — an emergency's live
    # status/location context shouldn't be readable by any logged-in
    # stranger just because they know the reference string.
    emergency = get_object_or_404(EmergencyReport, reference=reference)
    if emergency.user_id != request.user.id and not (request.user.is_staff or request.user.is_dashboard_admin):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
    return Response(EmergencyStatusSerializer(emergency).data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def mark_resolved(request, reference):
    # Lets the app itself close out an emergency (e.g. "I'm safe now"),
    # separate from an admin responding in the dashboard.
    emergency = get_object_or_404(EmergencyReport, reference=reference)
    if emergency.user_id != request.user.id:
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
    emergency.status = "resolved"
    if not emergency.responded_at:
        emergency.responded_at = timezone.now()
    emergency.save()
    return Response(EmergencyStatusSerializer(emergency).data)


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def contact_list_create(request):
    if request.method == "GET":
        contacts = request.user.emergency_contacts.all()
        return Response(EmergencyContactSerializer(contacts, many=True).data)

    serializer = EmergencyContactCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    own = EmergencyContact._normalize(request.user.phone_number)
    if own and EmergencyContact._normalize(serializer.validated_data["phone_number"]) == own:
        return Response(
            {"phone_number": ["That is your own number."]},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        # Saved as "pending": it only counts once the other person accepts.
        contact = serializer.save(owner=request.user, status="pending")
    except IntegrityError:
        return Response(
            {"phone_number": ["You've already added this number as an emergency contact."]},
            status=status.HTTP_400_BAD_REQUEST,
        )
    _notify_request(contact, request.user)
    return Response(EmergencyContactSerializer(contact).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def contact_add_user(request):
    """
    Add a person who already has an account (found in chat or on a
    community post) as an emergency contact. Sends them a request.
    Body: {"user_id": 12, "relationship": "Friend"}
    """
    try:
        user_id = int(request.data.get("user_id"))
    except (TypeError, ValueError):
        return Response({"user_id": ["Send the person's id."]}, status=status.HTTP_400_BAD_REQUEST)
    if user_id == request.user.id:
        return Response({"detail": "You can't add yourself."}, status=status.HTTP_400_BAD_REQUEST)

    person = get_object_or_404(get_user_model(), pk=user_id)
    if not person.phone_number:
        return Response(
            {"detail": "This person hasn't added a phone number to their account yet, so they can't be added."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    relationship = str(request.data.get("relationship") or "Friend").strip()[:30] or "Friend"
    try:
        contact = EmergencyContact.objects.create(
            owner=request.user,
            name=_who(person)[:150],
            phone_number=person.phone_number,
            relationship=relationship,
            status="pending",
        )
    except IntegrityError:
        return Response(
            {"detail": "This person is already in your emergency contacts."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    _notify_request(contact, request.user)
    return Response(EmergencyContactSerializer(contact).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def contact_requests(request):
    """Requests other people sent ME, waiting for me to accept or decline."""
    pending = EmergencyContact.requests_for(request.user).select_related("owner").order_by("-created_at")
    return Response(ContactRequestSerializer(pending, many=True, context={"request": request}).data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def contact_respond(request, pk):
    """
    Accept or decline a request. Body: {"action": "accept"} or {"action": "decline"}.

    Accepting works both ways: the person who asked becomes my contact AND I
    become theirs, so neither of us has to send a second request.
    """
    contact = get_object_or_404(EmergencyContact.all_pointing_to(request.user).select_related("owner"), pk=pk)

    action = str(request.data.get("action", "")).strip().lower()
    if action not in ("accept", "decline"):
        return Response({"action": ["Choose accept or decline."]}, status=status.HTTP_400_BAD_REQUEST)

    accepted = action == "accept"
    with transaction.atomic():
        contact.status = "accepted" if accepted else "declined"
        contact.responded_at = timezone.now()
        contact.save(update_fields=["status", "responded_at"])
        if accepted:
            _ensure_reverse_contact(accepter=request.user, requester=contact.owner)

    me = _who(request.user)
    _safely(
        send_notification,
        contact.owner,
        "alert",
        f"{me} accepted your emergency contact request. You are now each other's emergency contacts."
        if accepted
        else f"{me} declined your emergency contact request.",
        action="contact_response",
    )
    _safely(mark_handled, request.user, "contact_request", contact.id)

    return Response(
        {
            "id": contact.id,
            "status": contact.status,
            "detail": (
                f"You and {_who(contact.owner)} are now each other's emergency contacts."
                if accepted
                else "Request declined."
            ),
        },
        status=status.HTTP_200_OK,
    )


@api_view(["DELETE"])
@permission_classes([permissions.IsAuthenticated])
def contact_delete(request, pk):
    contact = get_object_or_404(EmergencyContact, pk=pk, owner=request.user)
    contact.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def alerts_for_me(request):
    # Active/ongoing emergencies from people who have this user saved
    # as one of THEIR emergency contacts (and this user accepted) — the
    # in-app equivalent of "the emergency contacts must get the alert".
    alerts = request.user.emergency_alerts_received.exclude(status__in=["resolved", "unresponded"]).order_by(
        "-created_at"
    )
    return Response(IncomingAlertSerializer(alerts, many=True).data)