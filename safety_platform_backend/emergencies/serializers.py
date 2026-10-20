from django.utils import timezone
from rest_framework import serializers
from .models import EmergencyContact, EmergencyReport


class EmergencyTriggerSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyReport
        fields = ["incident_type", "latitude", "longitude", "location_description"]


class EmergencyStatusSerializer(serializers.ModelSerializer):
    """
    What the Flutter app polls during its countdown
    (_EmergencyPopupState) to find out whether a real admin has
    responded within the window, and whether the window has lapsed —
    i.e. whether it's now honest to let the person generate a PONR
    certificate.
    """

    incident_type_display = serializers.CharField(source="get_incident_type_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    seconds_remaining = serializers.SerializerMethodField()

    class Meta:
        model = EmergencyReport
        fields = [
            "reference", "incident_type", "incident_type_display", "status", "status_display",
            "created_at", "responded_at", "is_overdue", "seconds_remaining",
        ]
        read_only_fields = fields

    def get_seconds_remaining(self, obj):
        if obj.responded_at or obj.status in ("resolved", "unresponded"):
            return 0
        remaining = (obj.response_deadline - timezone.now()).total_seconds()
        return max(0, int(remaining))


class EmergencyContactSerializer(serializers.ModelSerializer):
    """Read shape for 'Your Circle'. has_app and is_protected are computed live, never client-set."""

    has_app = serializers.BooleanField(read_only=True)
    is_protected = serializers.BooleanField(read_only=True)
    awaiting_response = serializers.BooleanField(read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)

    class Meta:
        model = EmergencyContact
        fields = [
            "id", "name", "phone_number", "relationship", "has_app",
            "status", "status_display", "is_protected", "awaiting_response", "created_at",
        ]
        read_only_fields = fields


class EmergencyContactCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ["name", "phone_number", "relationship"]


class ContactRequestSerializer(serializers.ModelSerializer):
    """A request someone sent ME: 'add me as your emergency contact'."""

    from_name = serializers.SerializerMethodField()
    from_phone = serializers.CharField(source="owner.phone_number", read_only=True)
    from_photo = serializers.SerializerMethodField()
    status_display = serializers.CharField(source="get_status_display", read_only=True)

    class Meta:
        model = EmergencyContact
        fields = [
            "id", "from_name", "from_phone", "from_photo",
            "relationship", "status", "status_display", "created_at",
        ]
        read_only_fields = fields

    def get_from_name(self, obj):
        return obj.owner.full_name or obj.owner.email

    def get_from_photo(self, obj):
        photo = getattr(obj.owner, "profile_photo", None)
        if not photo:
            return None
        url = photo.url
        request = self.context.get("request")
        return request.build_absolute_uri(url) if request else url


class IncomingAlertSerializer(serializers.ModelSerializer):
    """
    What alerts-for-me returns — an emergency triggered by someone who
    has the current user saved as one of their own emergency contacts.
    """

    reporter_name = serializers.SerializerMethodField()
    reporter_phone = serializers.CharField(source="user.phone_number", read_only=True)
    incident_type_display = serializers.CharField(source="get_incident_type_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)

    class Meta:
        model = EmergencyReport
        fields = [
            "reference", "reporter_name", "reporter_phone", "incident_type", "incident_type_display",
            "latitude", "longitude", "location_description", "status", "status_display", "created_at",
        ]
        read_only_fields = fields

    def get_reporter_name(self, obj):
        return obj.user.full_name if obj.user else "Unknown"