from django.utils import timezone
from rest_framework import serializers

from .models import (
    ALLOWED_EVIDENCE_EXTENSIONS,
    MAX_EVIDENCE_BYTES,
    MAX_EVIDENCE_FILES,
    Event,
    EventIncident,
    IncidentEvidence,
)


def validate_evidence_files(files):
    """Raises a 400 with a readable message if any uploaded file breaks the rules."""
    if len(files) > MAX_EVIDENCE_FILES:
        raise serializers.ValidationError({"evidence": [f"You can attach up to {MAX_EVIDENCE_FILES} files."]})
    for f in files:
        ext = f.name.rsplit(".", 1)[-1].lower() if "." in f.name else ""
        if ext not in ALLOWED_EVIDENCE_EXTENSIONS:
            raise serializers.ValidationError({"evidence": [f"'{f.name}' is not a supported file type."]})
        if f.size > MAX_EVIDENCE_BYTES:
            raise serializers.ValidationError({"evidence": [f"'{f.name}' is over the 50MB limit."]})


class EventSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source="get_category_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    latitude = serializers.FloatField(read_only=True)
    longitude = serializers.FloatField(read_only=True)
    host_name = serializers.SerializerMethodField()
    attendee_count = serializers.SerializerMethodField()
    attending = serializers.SerializerMethodField()
    is_host = serializers.SerializerMethodField()
    accepts_alerts = serializers.BooleanField(read_only=True)
    has_ended = serializers.BooleanField(read_only=True)
    open_incidents = serializers.SerializerMethodField()

    class Meta:
        model = Event
        fields = [
            "id", "title", "description", "category", "category_display",
            "venue_name", "address", "latitude", "longitude",
            "start_at", "end_at", "expected_attendance",
            "host_name", "host_phone", "security_head_name", "security_head_phone",
            "status", "status_display", "attendee_count", "attending", "is_host",
            "accepts_alerts", "has_ended", "open_incidents", "created_at",
        ]
        read_only_fields = fields

    def _user(self):
        request = self.context.get("request")
        return request.user if request and request.user.is_authenticated else None

    def get_host_name(self, obj):
        if not obj.host:
            return "Unknown"
        return obj.host.full_name or obj.host.email

    def get_attendee_count(self, obj):
        return obj.attendances.count()

    def get_attending(self, obj):
        user = self._user()
        return bool(user and obj.attendances.filter(user=user).exists())

    def get_is_host(self, obj):
        user = self._user()
        return bool(user and obj.host_id == user.id)

    def get_open_incidents(self, obj):
        user = self._user()
        if user and obj.host_id == user.id:
            return obj.open_incident_count
        return None


class EventCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Event
        fields = [
            "title", "description", "category", "venue_name", "address",
            "latitude", "longitude", "start_at", "end_at", "expected_attendance",
            "host_phone", "security_head_name", "security_head_phone",
        ]

    def validate(self, attrs):
        start, end = attrs["start_at"], attrs["end_at"]
        if end <= start:
            raise serializers.ValidationError({"end_at": ["The event must end after it starts."]})
        if end <= timezone.now():
            raise serializers.ValidationError({"end_at": ["The end time is in the past."]})
        return attrs


class IncidentCreateSerializer(serializers.Serializer):
    kind = serializers.ChoiceField(choices=EventIncident.KIND_CHOICES)
    description = serializers.CharField(required=False, allow_blank=True, max_length=2000)
    location_description = serializers.CharField(required=False, allow_blank=True, max_length=255)
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6, required=False, allow_null=True)
    is_anonymous = serializers.BooleanField(required=False, default=False)
    needs_immediate_help = serializers.BooleanField(required=False, default=False)

    def validate(self, attrs):
        if attrs["kind"] == "other" and not attrs.get("description", "").strip():
            raise serializers.ValidationError({"description": ["Please describe what is happening."]})
        return attrs


class IncidentEvidenceSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()
    file_kind = serializers.CharField(read_only=True)

    class Meta:
        model = IncidentEvidence
        fields = ["id", "url", "file_kind", "original_filename", "size_bytes"]
        read_only_fields = fields

    def get_url(self, obj):
        request = self.context.get("request")
        url = obj.file.url
        return request.build_absolute_uri(url) if request else url


class IncidentSerializer(serializers.ModelSerializer):
    """What the event host sees. admin_notes are never included."""

    kind_display = serializers.CharField(source="get_kind_display", read_only=True)
    severity_display = serializers.CharField(source="get_severity_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    latitude = serializers.FloatField(read_only=True)
    longitude = serializers.FloatField(read_only=True)
    reporter_name = serializers.CharField(source="reporter_label", read_only=True)
    evidence = IncidentEvidenceSerializer(many=True, read_only=True)

    class Meta:
        model = EventIncident
        fields = [
            "id", "reference", "kind", "kind_display", "severity", "severity_display",
            "status", "status_display", "description", "location_description",
            "latitude", "longitude", "is_anonymous", "reporter_name", "evidence",
            "created_at", "acknowledged_at", "resolved_at",
        ]
        read_only_fields = fields