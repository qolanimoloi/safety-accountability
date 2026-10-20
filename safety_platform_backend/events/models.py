import secrets
import uuid
from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone

# Safety alerts are accepted until this long after the event ends.
ALERT_GRACE_HOURS = 6

OPEN_STATUSES = ["new", "acknowledged", "responding"]

# Evidence rules: same file types and size limit as anonymous reporting.
MAX_EVIDENCE_FILES = 5
MAX_EVIDENCE_BYTES = 50 * 1024 * 1024  # 50MB per file
IMAGE_EXTENSIONS = {"jpg", "jpeg", "png"}
VIDEO_EXTENSIONS = {"mp4", "mov"}
AUDIO_EXTENSIONS = {"mp3", "wav"}
DOCUMENT_EXTENSIONS = {"pdf", "doc", "docx"}
ALLOWED_EVIDENCE_EXTENSIONS = IMAGE_EXTENSIONS | VIDEO_EXTENSIONS | AUDIO_EXTENSIONS | DOCUMENT_EXTENSIONS


class Event(models.Model):
    CATEGORY_CHOICES = [
        ("music", "Music / Concert"),
        ("sports", "Sports"),
        ("community", "Community gathering"),
        ("religious", "Religious"),
        ("festival", "Festival / Market"),
        ("political", "Rally / Political"),
        ("school", "School / Campus"),
        ("other", "Other"),
    ]
    STATUS_CHOICES = [
        ("published", "Published"),
        ("cancelled", "Cancelled by host"),
        ("hidden", "Hidden by admin"),
    ]

    host = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="hosted_events"
    )
    title = models.CharField(max_length=150)
    description = models.TextField()
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES, default="community")

    venue_name = models.CharField(max_length=150)
    address = models.CharField(max_length=255, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)

    start_at = models.DateTimeField()
    end_at = models.DateTimeField()
    expected_attendance = models.PositiveIntegerField(null=True, blank=True)

    host_phone = models.CharField(max_length=20)
    security_head_name = models.CharField(max_length=150, blank=True)
    security_head_phone = models.CharField(max_length=20, blank=True)

    status = models.CharField(max_length=12, choices=STATUS_CHOICES, default="published")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["start_at"]

    def __str__(self):
        return self.title

    @property
    def attendee_count(self):
        return self.attendances.count()

    @property
    def has_ended(self):
        return timezone.now() > self.end_at

    @property
    def is_live(self):
        now = timezone.now()
        return self.status == "published" and self.start_at <= now <= self.end_at

    @property
    def accepts_alerts(self):
        return self.status == "published" and timezone.now() < self.end_at + timedelta(hours=ALERT_GRACE_HOURS)

    @property
    def open_incident_count(self):
        return self.incidents.filter(status__in=OPEN_STATUSES).count()


class EventAttendance(models.Model):
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name="attendances")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="event_attendances")
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("event", "user")
        ordering = ["-joined_at"]

    def __str__(self):
        return f"{self.user} → {self.event}"


class EventIncident(models.Model):
    """
    A safety alert or report sent by someone at an event. When
    is_anonymous is True, `reporter` is never filled in: the server
    checks that the person joined the event but does not store who sent it.
    """

    KIND_CHOICES = [
        ("panic", "SOS - I need help now"),
        ("medical", "Medical emergency"),
        ("fire", "Fire / smoke"),
        ("violence", "Fight / violence"),
        ("harassment", "Harassment / GBV"),
        ("theft", "Theft / robbery"),
        ("suspicious", "Suspicious person or item"),
        ("lost_child", "Lost child / missing person"),
        ("crowd", "Overcrowding / crowd crush"),
        ("drugs", "Drug activity"),
        ("other", "Other"),
    ]
    DEFAULT_SEVERITY = {
        "panic": "critical",
        "medical": "critical",
        "fire": "critical",
        "violence": "high",
        "harassment": "high",
        "lost_child": "high",
        "crowd": "high",
        "theft": "medium",
        "suspicious": "medium",
        "drugs": "medium",
        "other": "low",
    }
    SEVERITY_CHOICES = [("low", "Low"), ("medium", "Medium"), ("high", "High"), ("critical", "Critical")]
    STATUS_CHOICES = [
        ("new", "New"),
        ("acknowledged", "Acknowledged"),
        ("responding", "Responding"),
        ("resolved", "Resolved"),
        ("false_alarm", "False alarm"),
    ]

    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name="incidents")
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    is_anonymous = models.BooleanField(default=False)

    kind = models.CharField(max_length=20, choices=KIND_CHOICES)
    severity = models.CharField(max_length=10, choices=SEVERITY_CHOICES, default="medium")
    description = models.TextField(blank=True)
    location_description = models.CharField(max_length=255, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)

    reference = models.CharField(max_length=20, unique=True, editable=False)
    status = models.CharField(max_length=15, choices=STATUS_CHOICES, default="new")
    acknowledged_at = models.DateTimeField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    handled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    admin_notes = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.reference} · {self.get_kind_display()}"

    @staticmethod
    def generate_reference():
        while True:
            ref = "EVT-" + secrets.token_hex(4).upper()
            if not EventIncident.objects.filter(reference=ref).exists():
                return ref

    def save(self, *args, **kwargs):
        if not self.reference:
            self.reference = self.generate_reference()
        super().save(*args, **kwargs)

    @property
    def is_open(self):
        return self.status in OPEN_STATUSES

    @property
    def evidence_count(self):
        return self.evidence.count()

    @property
    def reporter_label(self):
        if self.is_anonymous or not self.reporter:
            return "Anonymous"
        return self.reporter.full_name or self.reporter.email

    @property
    def severity_badge(self):
        return {"critical": "danger", "high": "warning text-dark", "medium": "info text-dark"}.get(
            self.severity, "secondary"
        )

    @property
    def status_badge(self):
        return {
            "new": "danger",
            "acknowledged": "warning text-dark",
            "responding": "primary",
            "resolved": "success",
        }.get(self.status, "secondary")

    def add_note(self, notes):
        notes = (notes or "").strip()
        if not notes:
            return
        stamp = timezone.now().strftime("%Y-%m-%d %H:%M")
        line = f"[{stamp}] {notes}"
        self.admin_notes = f"{self.admin_notes}\n{line}" if self.admin_notes else line

    def set_status(self, new_status, user=None, notes=""):
        now = timezone.now()
        self.status = new_status
        if new_status != "new" and not self.acknowledged_at:
            self.acknowledged_at = now
        self.resolved_at = now if new_status in ("resolved", "false_alarm") else None
        if user is not None:
            self.handled_by = user
        self.add_note(notes)
        self.save()


def incident_evidence_upload_path(instance, filename):
    # Random file names: nothing about the sender's phone or file name is
    # kept in the URL or on disk.
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
    return f"event_incidents/{instance.incident.reference}/{uuid.uuid4().hex}.{ext}"


class IncidentEvidence(models.Model):
    """One uploaded file (photo, video, audio, document) attached to an alert or report."""

    incident = models.ForeignKey(EventIncident, related_name="evidence", on_delete=models.CASCADE)
    file = models.FileField(upload_to=incident_evidence_upload_path)
    # Left blank for anonymous reports so the sender's file name is not kept.
    original_filename = models.CharField(max_length=255, blank=True)
    content_type = models.CharField(max_length=100, blank=True)
    size_bytes = models.PositiveIntegerField(default=0)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["uploaded_at", "id"]
        verbose_name_plural = "incident evidence"

    def __str__(self):
        return f"{self.incident.reference} · {self.original_filename or self.file.name}"

    @property
    def extension(self):
        name = self.file.name or ""
        return name.rsplit(".", 1)[-1].lower() if "." in name else ""

    @property
    def file_kind(self):
        ext = self.extension
        if ext in IMAGE_EXTENSIONS:
            return "image"
        if ext in VIDEO_EXTENSIONS:
            return "video"
        if ext in AUDIO_EXTENSIONS:
            return "audio"
        if ext in DOCUMENT_EXTENSIONS:
            return "document"
        return "other"