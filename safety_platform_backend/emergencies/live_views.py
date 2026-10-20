from datetime import timedelta
from decimal import Decimal, InvalidOperation

from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .models import (
    LIVE_LOCATION_HIDE_AFTER_SECONDS,
    LIVE_LOCATION_STALE_AFTER_SECONDS,
    EmergencyContact,
    LiveLocation,
)

# False: you see a contact who saved NOTHING about you, as long as YOU
#        saved THEM and THEY switched sharing on.
# True:  additionally requires that THEY also saved you as a contact.
REQUIRE_MUTUAL = False

MAX_DURATION_MINUTES = 24 * 60


def _own_location(user):
    loc, _ = LiveLocation.objects.get_or_create(user=user)
    if loc.is_sharing and not loc.is_active:
        loc.stop()  # the timer ran out: switch off and erase the position
    return loc


def _state(loc):
    return {
        "is_sharing": loc.is_active,
        "sharing_until": loc.sharing_until.isoformat() if loc.sharing_until else None,
    }


def _parse_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        v = value.strip().lower()
        if v in ("true", "1", "yes"):
            return True
        if v in ("false", "0", "no"):
            return False
    return None


def _parse_coord(value, low, high):
    try:
        number = Decimal(str(value)).quantize(Decimal("0.000001"))
    except (InvalidOperation, ValueError, TypeError):
        return None
    if number < Decimal(low) or number > Decimal(high):
        return None
    return number


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def live_me(request):
    """GET: my sharing state. POST {sharing: bool, duration_minutes: int|null}: switch it."""
    loc = _own_location(request.user)

    if request.method == "GET":
        return Response(_state(loc))

    sharing = _parse_bool(request.data.get("sharing"))
    if sharing is None:
        return Response({"sharing": ["Send true or false."]}, status=status.HTTP_400_BAD_REQUEST)

    if not sharing:
        loc.stop()
        return Response(_state(loc))

    until = None
    duration = request.data.get("duration_minutes")
    if duration not in (None, ""):
        try:
            minutes = int(duration)
        except (TypeError, ValueError):
            minutes = 0
        if minutes < 1 or minutes > MAX_DURATION_MINUTES:
            return Response(
                {"duration_minutes": [f"Choose between 1 and {MAX_DURATION_MINUTES} minutes."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        until = timezone.now() + timedelta(minutes=minutes)

    loc.is_sharing = True
    loc.sharing_until = until
    loc.save()
    return Response(_state(loc))


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def live_update(request):
    """The app calls this every ~25s while sharing. Ignored (409) if sharing is off."""
    loc = _own_location(request.user)
    if not loc.is_active:
        return Response(
            {"detail": "Location sharing is off.", "is_sharing": False},
            status=status.HTTP_409_CONFLICT,
        )

    lat = _parse_coord(request.data.get("latitude"), -90, 90)
    lng = _parse_coord(request.data.get("longitude"), -180, 180)
    if lat is None or lng is None:
        return Response({"detail": "A valid latitude and longitude are required."}, status=status.HTTP_400_BAD_REQUEST)

    accuracy = None
    try:
        accuracy = float(request.data.get("accuracy_m"))
        if accuracy < 0 or accuracy > 100000:
            accuracy = None
    except (TypeError, ValueError):
        accuracy = None

    loc.latitude = lat
    loc.longitude = lng
    loc.accuracy_m = accuracy
    loc.position_updated_at = timezone.now()
    loc.save()
    return Response({"ok": True, "is_sharing": True})


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def live_contacts(request):
    """Contacts I saved, who have the app AND are currently sharing their location."""
    viewer = request.user

    allowed_owner_ids = None
    if REQUIRE_MUTUAL:
        allowed_owner_ids = set(
            EmergencyContact.contacts_pointing_to(viewer).values_list("owner_id", flat=True)
        )

    contact_by_user = {}
    for contact in viewer.emergency_contacts.filter(status="accepted"):
        person = contact.linked_user
        if not person or person.id == viewer.id:
            continue
        if allowed_owner_ids is not None and person.id not in allowed_owner_ids:
            continue
        contact_by_user[person.id] = contact

    if not contact_by_user:
        return Response([])

    locations = LiveLocation.objects.filter(
        user_id__in=contact_by_user.keys(), is_sharing=True, latitude__isnull=False, longitude__isnull=False
    )

    now = timezone.now()
    result = []
    for loc in locations:
        if not loc.is_active or not loc.position_updated_at:
            continue
        seconds_ago = max(0, int((now - loc.position_updated_at).total_seconds()))
        if seconds_ago > LIVE_LOCATION_HIDE_AFTER_SECONDS:
            continue
        contact = contact_by_user[loc.user_id]
        result.append(
            {
                "contact_id": contact.id,
                "user_id": loc.user_id,
                "name": contact.name,
                "relationship": contact.relationship,
                "phone_number": contact.phone_number,
                "latitude": float(loc.latitude),
                "longitude": float(loc.longitude),
                "accuracy_m": loc.accuracy_m,
                "updated_at": loc.position_updated_at.isoformat(),
                "seconds_ago": seconds_ago,
                "is_stale": seconds_ago > LIVE_LOCATION_STALE_AFTER_SECONDS,
            }
        )
    return Response(result)