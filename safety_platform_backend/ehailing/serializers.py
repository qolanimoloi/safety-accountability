from django.utils import timezone
from rest_framework import serializers
from .models import (
    DriverCommunity,
    DriverCommunityPost,
    EhailingPanicAlert,
    PassengerLog,
    Trip,
)


class TripSerializer(serializers.ModelSerializer):
    service_display = serializers.CharField(source="get_service_display", read_only=True)

    class Meta:
        model = Trip
        fields = [
            "id", "service", "service_display", "driver_name", "vehicle_reg",
            "vehicle_model", "vehicle_color", "pickup_location", "destination_location",
            "verification_pin", "status", "started_at", "ended_at",
        ]
        read_only_fields = ["id", "status", "started_at", "ended_at"]


class TripCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Trip
        fields = [
            "service", "driver_name", "vehicle_reg", "vehicle_model",
            "vehicle_color", "pickup_location", "destination_location", "verification_pin",
        ]


class DriverCommunitySerializer(serializers.ModelSerializer):
    member_count = serializers.IntegerField(read_only=True)
    is_member = serializers.SerializerMethodField()

    class Meta:
        model = DriverCommunity
        fields = ["id", "name", "area", "member_count", "is_member", "created_at"]

    def get_is_member(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        return obj.members.filter(pk=request.user.pk).exists()


class DriverCommunityCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = DriverCommunity
        fields = ["name", "area"]


class DriverCommunityPostSerializer(serializers.ModelSerializer):
    driver_name = serializers.SerializerMethodField()

    class Meta:
        model = DriverCommunityPost
        fields = ["id", "driver_name", "message", "created_at"]
        read_only_fields = ["id", "driver_name", "created_at"]

    def get_driver_name(self, obj):
        if not obj.driver:
            return "Unknown"
        return obj.driver.full_name or obj.driver.email


class DriverCommunityPostCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = DriverCommunityPost
        fields = ["message"]


class PassengerLogSerializer(serializers.ModelSerializer):
    photo = serializers.SerializerMethodField()

    class Meta:
        model = PassengerLog
        fields = [
            "id", "passenger_name", "passenger_phone", "pickup_location",
            "destination_location", "passenger_count", "notes", "photo",
            "trip_pin", "auto_check_in", "status", "logged_at", "dropped_off_at",
        ]
        read_only_fields = ["id", "trip_pin", "status", "logged_at", "dropped_off_at"]

    def get_photo(self, obj):
        if not obj.photo:
            return None
        request = self.context.get("request")
        url = obj.photo.url
        return request.build_absolute_uri(url) if request else url


class PassengerLogCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PassengerLog
        fields = [
            "passenger_name", "passenger_phone", "pickup_location",
            "destination_location", "passenger_count", "notes", "photo", "auto_check_in",
        ]


class EhailingPanicAlertSerializer(serializers.ModelSerializer):
    seconds_remaining = serializers.SerializerMethodField()

    class Meta:
        model = EhailingPanicAlert
        fields = [
            "id", "role", "trip", "passenger_log", "community",
            "latitude", "longitude", "status", "seconds_remaining",
            "is_overdue", "created_at",
        ]
        read_only_fields = fields

    def get_seconds_remaining(self, obj):
        return max(0, int((obj.response_deadline - timezone.now()).total_seconds()))