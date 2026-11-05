from datetime import timedelta

from django.utils import timezone
from rest_framework.authentication import TokenAuthentication

# The "last seen" time is saved at most once a minute per person, so it
# costs the server almost nothing.
LAST_SEEN_REFRESH = timedelta(seconds=60)


class LastSeenTokenAuthentication(TokenAuthentication):
    """
    Works exactly like the normal token login, and also remembers when the
    person was last active. Every API call the app makes counts as activity.
    """

    def authenticate(self, request):
        result = super().authenticate(request)
        if result is not None:
            user = result[0]
            now = timezone.now()
            last = getattr(user, "last_seen", None)
            if last is None or now - last >= LAST_SEEN_REFRESH:
                try:
                    type(user).objects.filter(pk=user.pk).update(last_seen=now)
                    user.last_seen = now
                except Exception:
                    # Never block a real request just because this note could not be saved.
                    pass
        return result