from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone

ACTIVITY_TYPE_CHOICES = [
    ("date", "Date"),
    ("travel", "Travel"),
    ("meeting_new_person", "Meeting New Person"),
    ("job_interview", "Job Interview"),
    ("property_viewing", "Property Viewing"),
    ("ride_share", "Ride Share"),
    ("online_purchase_meetup", "Online Purchase Meetup"),
    ("other", "Other"),
]

# If an activity has no expected return time, a contact may escalate it
# this many hours after it started.
NO_RETURN_TIME_GRACE_HOURS = 6

# What the admin team is doing about an escalated activity.
ADMIN_STATUS_CHOICES = [
    ("new", "New: awaiting admin"),
    ("acknowledged", "Acknowledged"),
    ("responding", "Responding"),
    ("authorities", "Authorities notified"),
    ("resolved", "Resolved: person is safe"),
    ("false_alarm", "False alarm"),
]
ADMIN_OPEN_STATUSES = ["new", "acknowledged", "responding", "authorities"]
ADMIN_CLOSED_STATUSES = ["resolved", "false_alarm"]


def person_photo_upload_path(instance, filename):
    return f"activity_log/{instance.pk or 'new'}/person_{filename}"


def car_photo_upload_path(instance, filename):
    return f"activity_log/{instance.pk or 'new'}/car_{filename}"


class LoggedActivity(models.Model):
    """
    Backs log_page.dart's "Activity Log" — a personal safety record a
    user creates before meeting someone new or going somewhere
    unfamiliar: who they're meeting, where, when they expect to be
    back, and optional photos of the person/vehicle as a record if
    something goes wrong.

    PRIVACY RULE: a logged activity is visible only to its owner and to
    the people who saved that owner as an emergency contact. The admin
    team sees it ONLY after one of those contacts escalates it because
    the person did not return (escalated_at is set). Until then it never
    appears anywhere in the admin dashboard.
    """

    STATUS_CHOICES = [
        ("upcoming", "Upcoming"),
        ("active", "Active"),
        ("completed", "Completed"),
        ("cancelled", "Cancelled"),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="logged_activities")

    activity_type = models.CharField(max_length=30, choices=ACTIVITY_TYPE_CHOICES, default="other")
    scheduled_at = models.DateTimeField()
    expected_return_at = models.DateTimeField(null=True, blank=True)
    location = models.CharField(max_length=255)

    person_name = models.CharField(max_length=150, blank=True)
    person_photo = models.ImageField(upload_to=person_photo_upload_path, null=True, blank=True)

    car_reg = models.CharField(max_length=30, blank=True)
    car_photo = models.ImageField(upload_to=car_photo_upload_path, null=True, blank=True)

    notes = models.TextField(blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default="upcoming")

    # ---- Escalation: set when an emergency contact sends this to the admin team ----
    escalated_at = models.DateTimeField(null=True, blank=True)
    escalated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="escalated_activities"
    )
    escalation_note = models.TextField(blank=True)

    # Blank until escalated. Then tracks what the admin team is doing.
    admin_status = models.CharField(max_length=15, choices=ADMIN_STATUS_CHOICES, blank=True, default="")
    admin_notes = models.TextField(blank=True)
    admin_handled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    admin_updated_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-scheduled_at"]
        verbose_name_plural = "logged activities"

    def __str__(self):
        return f"{self.get_activity_type_display()} · {self.location} ({self.get_status_display()})"

    @property
    def is_overdue(self):
        if self.status in ("completed", "cancelled"):
            return False
        if not self.expected_return_at:
            return False
        return timezone.now() > self.expected_return_at

    @property
    def return_deadline(self):
        """When the person should have been back (with a fallback if none was set)."""
        if self.expected_return_at:
            return self.expected_return_at
        return self.scheduled_at + timedelta(hours=NO_RETURN_TIME_GRACE_HOURS)

    @property
    def is_escalated(self):
        return self.escalated_at is not None

    @property
    def can_escalate(self):
        """True when a contact is allowed to send this to the admin team."""
        if self.is_escalated:
            return False
        if self.status in ("completed", "cancelled"):
            return False
        return timezone.now() > self.return_deadline

    @property
    def admin_is_open(self):
        return self.is_escalated and self.admin_status in ADMIN_OPEN_STATUSES

    @property
    def admin_status_badge(self):
        return {
            "new": "danger",
            "acknowledged": "warning text-dark",
            "responding": "primary",
            "authorities": "dark",
            "resolved": "success",
        }.get(self.admin_status, "secondary")

    def escalate(self, by_user, note=""):
        now = timezone.now()
        self.escalated_at = now
        self.escalated_by = by_user
        self.escalation_note = (note or "").strip()[:500]
        self.admin_status = "new"
        self.admin_updated_at = now
        self.save()

    def add_admin_note(self, notes):
        notes = (notes or "").strip()
        if not notes:
            return
        stamp = timezone.now().strftime("%Y-%m-%d %H:%M")
        line = f"[{stamp}] {notes}"
        self.admin_notes = f"{self.admin_notes}\n{line}" if self.admin_notes else line

    def set_admin_status(self, new_status, user=None, notes=""):
        self.admin_status = new_status
        self.admin_updated_at = timezone.now()
        if user is not None:
            self.admin_handled_by = user
        # Closing the case also closes the activity, so the person's
        # contacts stop seeing it as overdue.
        if new_status in ADMIN_CLOSED_STATUSES and self.status not in ("completed", "cancelled"):
            self.status = "completed"
        self.add_admin_note(notes)
        self.save()