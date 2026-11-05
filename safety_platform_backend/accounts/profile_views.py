from datetime import timedelta

from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .models import User

# Someone active in the last 2 minutes is shown as "Online".
ONLINE_WINDOW = timedelta(minutes=2)


def _initials(name):
    parts = [p for p in (name or "").split() if p]
    if not parts:
        return "?"
    if len(parts) == 1:
        return parts[0][0].upper()
    return (parts[0][0] + parts[1][0]).upper()


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def public_profile(request, pk):
    """
    What another person is allowed to see about someone: name, picture,
    whether they are an official account, and (only if they allow it)
    when they were last seen. Never the email or phone number.
    """
    user = get_object_or_404(User, pk=pk, is_active_account=True)
    is_me = user.pk == request.user.pk

    photo_url = None
    if user.profile_photo:
        photo_url = request.build_absolute_uri(user.profile_photo.url)

    hidden = (not user.show_last_seen) and not is_me
    last_seen = None if hidden or user.last_seen is None else user.last_seen
    online = bool(last_seen and timezone.now() - last_seen <= ONLINE_WINDOW)

    name = user.full_name or "Safety & Accountability member"
    return Response(
        {
            "id": user.pk,
            "name": name,
            "initials": _initials(user.full_name),
            "photo_url": photo_url,
            "is_official": bool(user.is_dashboard_admin or user.is_superuser),
            "is_me": is_me,
            "member_since": user.date_joined_app.date().isoformat() if user.date_joined_app else None,
            "last_seen": last_seen.isoformat() if last_seen else None,
            "last_seen_hidden": hidden,
            "online": online,
            "show_last_seen": user.show_last_seen if is_me else None,
        }
    )


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        v = value.strip().lower()
        if v in ("true", "1", "yes", "on"):
            return True
        if v in ("false", "0", "no", "off"):
            return False
    return None


@api_view(["GET", "POST", "PATCH"])
@permission_classes([permissions.IsAuthenticated])
def privacy_settings(request):
    """GET shows, POST/PATCH changes, the 'Show my last seen' switch."""
    if request.method != "GET":
        value = _as_bool(request.data.get("show_last_seen"))
        if value is None:
            return Response(
                {"detail": "show_last_seen must be true or false."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.show_last_seen = value
        request.user.save(update_fields=["show_last_seen"])
    return Response({"show_last_seen": request.user.show_last_seen})