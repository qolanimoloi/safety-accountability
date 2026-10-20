from django.conf import settings
from django.db import models
from django.utils import timezone
from django.utils.functional import cached_property

RESPONSE_WINDOW_SECONDS = 10  # TESTING ONLY — set back to RESPONSE_WINDOW_MINUTES = 5 (and update response_deadline below) before going live

# Live location sharing: a position older than STALE_AFTER is shown greyed out
# in the app, and older than HIDE_AFTER is not returned at all.
LIVE_LOCATION_STALE_AFTER_SECONDS = 5 * 60
LIVE_LOCATION_HIDE_AFTER_SECONDS = 2 * 60 * 60


class EmergencyReport(models.Model):
    """
    Backs emergency_page.dart. Unlike AnonymousReport, this one IS tied
    to a logged-in user (the app requires login to reach this screen at
    all — isLoggedIn gates HomeScreen), so an admin responding to a live
    emergency can see who and where, not just an anonymous description.

    The Flutter page currently fakes a 5-SECOND countdown and builds the
    PONR PDF entirely on-device with placeholder text ("Captured via
    GPS", a hardcoded CEO signatory) — nothing from a backend. This
    model is what turns that into something real: the app reports the
    emergency here, the dashboard is where an admin actually responds
    within the real 5-MINUTE window, and the PONR certificate becomes
    true only when that window closes with no admin response.
    """

    INCIDENT_TYPE_CHOICES = [
        ("break_in", "Break-In"),
        ("being_followed", "Being Followed"),
        ("hijacking", "Hijacking"),
        ("domestic_violence", "Domestic Violence"),
        ("medical_emergency", "Medical Emergency"),
        ("fire", "Fire"),
        ("assault", "Assault"),
        ("other", "Other"),
    ]

    STATUS_CHOICES = [
        ("active", "Active — awaiting response"),
        ("responding", "Admin responding"),
        ("resolved", "Resolved"),
        ("unresponded", "Unresponded (PONR issued)"),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="emergency_reports",
        help_text="Who triggered this. Nullable only so a deleted account doesn't break historical records.",
    )

    incident_type = models.CharField(max_length=30, choices=INCIDENT_TYPE_CHOICES)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    location_description = models.CharField(max_length=255, blank=True)

    reference = models.CharField(max_length=30, unique=True, editable=False)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="active")

    # Set the moment an admin picks this up in the dashboard — this is
    # what the app polls for to stop its own countdown and skip the
    # PONR flow, exactly where _EmergencyPopupState's timer currently
    # has nothing real to check against.
    responded_at = models.DateTimeField(null=True, blank=True)
    response_notes = models.TextField(blank=True)

    # Registered accounts (from the reporter's own emergency-contacts
    # list) who get this alert in-app alongside the admin dashboard —
    # populated at trigger time in trigger_emergency(), not editable by
    # the client.
    notified_contacts = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        related_name="emergency_alerts_received",
        blank=True,
        help_text="Registered users who are an emergency contact of the reporter and were alerted in-app.",
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.reference} · {self.get_incident_type_display()}"

    @staticmethod
    def generate_reference():
        # Mirrors the app's own 'PONR-${millisecondsSinceEpoch}' shape
        # closely enough to be recognizable, but collision-checked
        # since multiple emergencies can land in the same millisecond
        # once this is server-generated instead of client-generated.
        import random

        while True:
            ref = f"EMG-{timezone.now().strftime('%Y%m%d%H%M%S')}-{random.randint(100, 999)}"
            if not EmergencyReport.objects.filter(reference=ref).exists():
                return ref

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self.generate_reference()
        super().save(*args, **kwargs)

    @property
    def response_deadline(self):
        return self.created_at + timezone.timedelta(seconds=RESPONSE_WINDOW_SECONDS)

    @property
    def is_overdue(self):
        # True once the real 5-minute window has passed with no admin
        # response — this is the actual condition a PONR certificate
        # should represent, rather than the client-side 5-second mock.
        if self.responded_at or self.status in ("resolved", "unresponded"):
            return False
        return timezone.now() > self.response_deadline


class EmergencyContact(models.Model):
    """
    Backs contacts_page.dart ("Your Circle"). A contact is picked from
    the user's phone contact book (flutter_contacts) and stored here by
    name/phone/relationship. Whether that phone number belongs to a
    registered account on this platform — and is therefore actually
    reachable with a live in-app alert — is NOT stored as a flag. It's
    computed fresh every time from the live accounts table (see
    has_app below), so a contact who installs the app later flips from
    Pending to Protected automatically with no extra action needed.

    CONSENT: a contact only counts (alerts, live location, activity
    sharing) once the other person has ACCEPTED the request. The API
    saves every new contact as "pending". The model default is
    "accepted" only so contacts saved before requests existed keep working.
    """

    STATUS_CHOICES = [
        ("pending", "Waiting for them to accept"),
        ("accepted", "Accepted"),
        ("declined", "Declined"),
    ]

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="emergency_contacts",
    )
    name = models.CharField(max_length=150)
    phone_number = models.CharField(max_length=20)
    relationship = models.CharField(max_length=30)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default="accepted")
    responded_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        unique_together = ("owner", "phone_number")

    def __str__(self):
        return f"{self.name} ({self.relationship}) — contact of {self.owner}"

    @staticmethod
    def _normalize(phone):
        # Loose match on the last 9 digits so "+27 71 234 5678",
        # "0712345678" and "27712345678" — the same SA number typed
        # three different ways by two different people — still line up.
        # Not a full E.164 parser, just enough for comparing numbers
        # between a contact book entry and a signup form.
        digits = "".join(ch for ch in (phone or "") if ch.isdigit())
        return digits[-9:] if len(digits) >= 9 else digits

    @cached_property
    def linked_user(self):
        norm = self._normalize(self.phone_number)
        if not norm:
            return None
        from django.contrib.auth import get_user_model

        User = get_user_model()
        for candidate in User.objects.exclude(phone_number=""):
            if self._normalize(candidate.phone_number) == norm:
                return candidate
        return None

    @property
    def has_app(self):
        return self.linked_user is not None

    @property
    def is_protected(self):
        """The person has the app AND accepted: alerts really reach them."""
        return self.has_app and self.status == "accepted"

    @property
    def awaiting_response(self):
        return self.has_app and self.status == "pending"

    @classmethod
    def all_pointing_to(cls, user):
        """Every contact row (any status, created by OTHER people) that resolves to this user by phone."""
        norm = cls._normalize(user.phone_number)
        if not norm:
            return cls.objects.none()
        matching_ids = [c.id for c in cls.objects.exclude(owner=user) if cls._normalize(c.phone_number) == norm]
        return cls.objects.filter(id__in=matching_ids)

    @classmethod
    def contacts_pointing_to(cls, user):
        """
        Reverse lookup of ACCEPTED contacts only: the people whose circle
        this user is truly part of. Used by activity-log sharing and
        escalation, and by live location. The admin dashboard never
        touches this path.
        """
        return cls.all_pointing_to(user).filter(status="accepted")

    @classmethod
    def requests_for(cls, user):
        """Requests waiting for this user to accept or decline."""
        return cls.all_pointing_to(user).filter(status="pending")


class LiveLocation(models.Model):
    """
    One row per user holding ONLY their latest shared position — no
    history is kept. Sharing is opt-in: is_sharing defaults to False and
    nothing is ever stored or returned until the user switches it on in
    the app. sharing_until (optional) makes it switch itself off.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="live_location",
    )
    is_sharing = models.BooleanField(default=False)
    sharing_until = models.DateTimeField(null=True, blank=True)

    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    accuracy_m = models.FloatField(null=True, blank=True)
    position_updated_at = models.DateTimeField(null=True, blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user} — {'sharing' if self.is_active else 'not sharing'}"

    @property
    def is_active(self):
        if not self.is_sharing:
            return False
        return self.sharing_until is None or timezone.now() < self.sharing_until

    def stop(self):
        """Switch sharing off and erase the stored position."""
        self.is_sharing = False
        self.sharing_until = None
        self.latitude = None
        self.longitude = None
        self.accuracy_m = None
        self.position_updated_at = None
        self.save()