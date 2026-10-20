from rest_framework import serializers
from .models import LoggedActivity

class LoggedActivitySerializer(serializers.ModelSerializer):
    activity_type_display = serializers.CharField(source="get_activity_type_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    person_photo = serializers.SerializerMethodField()
    car_photo = serializers.SerializerMethodField()
    is_overdue = serializers.BooleanField(read_only=True)
    logger_name = serializers.SerializerMethodField()
    logger_phone = serializers.SerializerMethodField()
    is_escalated = serializers.BooleanField(read_only=True)
    can_escalate = serializers.BooleanField(read_only=True)
    admin_status_display = serializers.SerializerMethodField()

    class Meta:
        model = LoggedActivity
        fields = [
            "id", "activity_type", "activity_type_display", "scheduled_at",
            "expected_return_at", "location", "person_name", "person_photo",
            "car_reg", "car_photo", "notes", "status", "status_display",
            "is_overdue", "created_at", "logger_name", "logger_phone",
            "is_escalated", "can_escalate", "escalated_at",
            "admin_status", "admin_status_display",
        ]
        read_only_fields = [
            "id", "status", "created_at", "logger_name", "logger_phone",
            "escalated_at", "admin_status",
        ]

    def get_person_photo(self, obj):
        return self._absolute_url(obj.person_photo)

    def get_car_photo(self, obj):
        return self._absolute_url(obj.car_photo)

    def get_logger_name(self, obj):
        return obj.user.full_name if obj.user else None

    def get_logger_phone(self, obj):
        return obj.user.phone_number if obj.user else None

    def get_admin_status_display(self, obj):
        return obj.get_admin_status_display() if obj.admin_status else None

    def _absolute_url(self, field_file):
        if not field_file:
            return None
        request = self.context.get("request")
        url = field_file.url
        return request.build_absolute_uri(url) if request else url


class LoggedActivityCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = LoggedActivity
        fields = [
            "activity_type", "scheduled_at", "expected_return_at", "location",
            "person_name", "person_photo", "car_reg", "car_photo", "notes",
        ]