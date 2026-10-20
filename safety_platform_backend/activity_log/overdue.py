from datetime import timedelta

from django.db.models import Q
from django.utils import timezone

from emergencies.models import EmergencyContact
from notifications.models import Notification

from .models import NO_RETURN_TIME_GRACE_HOURS, LoggedActivity


def _clip(text, n=255):
    text = text or ""
    return text if len(text) <= n else text[: n - 1] + "…"


def notify_overdue_for_contact(user):
    """
    Tells `user` the moment someone who listed them as an emergency contact
    is overdue, so the bell rings straight away and they can open
    Log > My Contacts and tap "Send to admin".

    Nothing in the database ticks on its own, so this runs whenever the
    user's app asks for its notifications (every ~10 seconds). Each overdue
    activity produces exactly one notification per contact; the tag
    "(activity #id)" at the end of the message is how repeats are avoided.
    """
    owner_ids = list(EmergencyContact.contacts_pointing_to(user).values_list("owner_id", flat=True))
    if not owner_ids:
        return

    now = timezone.now()
    overdue = (
        LoggedActivity.objects.filter(user_id__in=owner_ids, escalated_at__isnull=True)
        .exclude(status__in=["completed", "cancelled"])
        .filter(
            Q(expected_return_at__lt=now)
            | Q(expected_return_at__isnull=True, scheduled_at__lt=now - timedelta(hours=NO_RETURN_TIME_GRACE_HOURS))
        )
        .select_related("user")
    )

    for activity in overdue:
        tag = f"(activity #{activity.pk})"
        if Notification.objects.filter(user=user, message__endswith=tag).exists():
            continue
        who = _clip((activity.user.full_name or activity.user.email) if activity.user else "Someone", 60)
        Notification.notify(
            user,
            "alert",
            _clip(f"{who} has not returned by their expected time. Open Log > My Contacts to send to admin. {tag}", 255),
        )