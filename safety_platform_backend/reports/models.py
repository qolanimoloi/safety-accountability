import random
import string

from django.db import models


class AnonymousReport(models.Model):
    """
    Backs anonymous_page.dart. Deliberately has NO link to a User account
    — the Flutter page explicitly promises "Your identity is completely
    protected" / "no personal information is stored", so this model must
    stay that way even though accounts.User exists. A submitter's only
    way back into their own report is the tracking_code, exactly like
    the Flutter mock already behaves.
    """

    CATEGORY_CHOICES = [
        ("drug_activity", "Drug Activity"),
        ("sexual_harassment", "Sexual Harassment"),
        ("sexual_abuse", "Sexual Abuse"),
        ("gbv", "GBV"),
        ("child_abuse", "Child Abuse"),
        ("human_trafficking", "Human Trafficking"),
        ("corruption", "Corruption"),
        ("illegal_campaign", "Illegal Campaign"),
        ("domestic_violence", "Domestic Violence"),
        ("other", "Other"),
    ]

    URGENCY_CHOICES = [
        ("low", "Low"),
        ("medium", "Medium"),
        ("high", "High"),
        ("critical", "Critical"),
    ]

    STATUS_CHOICES = [
        ("submitted", "Submitted"),
        ("under_investigation", "Under Investigation"),
        ("resolved", "Resolved"),
    ]

    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES)
    location = models.CharField(max_length=255, blank=True)
    description = models.TextField()
    urgency = models.CharField(max_length=10, choices=URGENCY_CHOICES, default="medium")
    involves_minors = models.BooleanField(default=False)
    requires_immediate_action = models.BooleanField(default=False)

    tracking_code = models.CharField(max_length=20, unique=True, editable=False)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="submitted")

    # Admin-only notes from investigation — never exposed on the
    # tracking-code lookup API, since that endpoint is public/anonymous.
    admin_notes = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.tracking_code} · {self.get_category_display()}"

    @staticmethod
    def generate_tracking_code():
        # Matches the ANO-YYYY-#### pattern already used in the Flutter
        # mock (_submitReport), so codes people may have already noted
        # down during testing keep the same shape.
        from django.utils import timezone

        year = timezone.now().year
        while True:
            suffix = "".join(random.choices(string.digits, k=4))
            code = f"ANO-{year}-{suffix}"
            if not AnonymousReport.objects.filter(tracking_code=code).exists():
                return code

    def save(self, *args, **kwargs):
        if not self.tracking_code:
            self.tracking_code = self.generate_tracking_code()
        super().save(*args, **kwargs)


def evidence_upload_path(instance, filename):
    return f"anonymous_reports/{instance.report.tracking_code}/{filename}"


IMAGE_EXTENSIONS = {"jpg", "jpeg", "png"}
VIDEO_EXTENSIONS = {"mp4", "mov"}
AUDIO_EXTENSIONS = {"mp3", "wav"}
DOCUMENT_EXTENSIONS = {"pdf", "doc", "docx"}


class ReportEvidence(models.Model):
    """
    One row per uploaded file (anonymous_page.dart's file picker allows
    multiple: jpg/png/mp4/mov/mp3/wav/pdf/doc/docx, max 50MB each —
    size is checked in the serializer, not enforced by the DB).
    """

    report = models.ForeignKey(AnonymousReport, related_name="evidence", on_delete=models.CASCADE)
    file = models.FileField(upload_to=evidence_upload_path)
    original_filename = models.CharField(max_length=255)
    content_type = models.CharField(max_length=100, blank=True)
    size_bytes = models.PositiveIntegerField(default=0)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.original_filename

    @property
    def extension(self):
        name = self.original_filename or self.file.name
        return name.rsplit(".", 1)[-1].lower() if "." in name else ""

    @property
    def file_kind(self):
        """
        Used by the dashboard templates to decide how to preview this
        file — an <img>, an <audio> player, a <video> player, or just a
        download link for documents. Based on the extension rather than
        content_type because browsers/devices don't always send a
        reliable MIME type on upload.
        """
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