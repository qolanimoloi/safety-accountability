import random

from django.conf import settings
from django.db import models
from django.utils import timezone

RESPONSE_WINDOW_MINUTES = 5  # same window as emergencies.EmergencyReport, for a consistent dashboard SLA

SERVICE_CHOICES = [
    ("uber", "Uber"),
    ("bolt", "Bolt"),
    ("maxim", "Maxim"),
    ("indriver", "InDriver"),
    ("didi", "DiDi"),
]


class Trip(models.Model):
    """
    Backs the Passenger side of ehailing_page.dart. Created when the
    passenger taps "Share Trip With Emergency Contacts". verification_pin
    is whatever the passenger typed in after being told it by the driver
    — it's stored for the record, not validated against anything server
    side (the app has no way to know the real driver's PIN).
    """

    STATUS_CHOICES = [
        ("active", "Active"),
        ("ended", "Ended"),
    ]

    passenger = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="ehailing_trips")
    service = models.CharField(max_length=20, choices=SERVICE_CHOICES)

    driver_name = models.CharField(max_length=150)
    vehicle_reg = models.CharField(max_length=30)
    vehicle_model = models.CharField(max_length=100, blank=True)
    vehicle_color = models.CharField(max_length=50, blank=True)
    pickup_location = models.CharField(max_length=255, blank=True)
    destination_location = models.CharField(max_length=255, blank=True)
    verification_pin = models.CharField(max_length=20, blank=True)

    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default="active")
    started_at = models.DateTimeField(auto_now_add=True)
    ended_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-started_at"]

    def __str__(self):
        return f"{self.get_service_display()} trip · {self.driver_name} ({self.get_status_display()})"


class DriverCommunity(models.Model):
    """
    Backs "Driver Community" in the Driver view — join one of the
    available ones, or create a new one (the creator auto-joins, same
    as _createCommunity in the Flutter mock).
    """

    name = models.CharField(max_length=150)
    area = models.CharField(max_length=150, blank=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="ehailing_communities_created")
    members = models.ManyToManyField(settings.AUTH_USER_MODEL, blank=True, related_name="ehailing_communities")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]
        verbose_name_plural = "driver communities"

    def __str__(self):
        return self.name

    @property
    def member_count(self):
        return self.members.count()


class DriverCommunityPost(models.Model):
    """
    The "Real-time updates from drivers in your community" feed — a
    lightweight feed scoped to one DriverCommunity, separate from the
    main community.CommunityPost feed since this one is driver-only and
    tied to a specific community rather than public/location-based.
    """

    community = models.ForeignKey(DriverCommunity, related_name="posts", on_delete=models.CASCADE)
    driver = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="ehailing_posts")
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.driver} in {self.community}: {self.message[:40]}"


def passenger_photo_upload_path(instance, filename):
    return f"ehailing_passenger_logs/{instance.pk or 'new'}/{filename}"


class PassengerLog(models.Model):
    """
    Backs "Log This Passenger" on the Driver side. trip_pin is generated
    server-side (not trusted from the client) the same way the Flutter
    mock did it locally: a random 4-digit number, told to the passenger
    out loud so they can confirm they're getting into the right car.
    """

    STATUS_CHOICES = [
        ("active", "Active"),
        ("completed", "Completed"),
    ]

    driver = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="ehailing_passenger_logs")
    community = models.ForeignKey(DriverCommunity, null=True, blank=True, on_delete=models.SET_NULL, related_name="passenger_logs")

    passenger_name = models.CharField(max_length=150)
    passenger_phone = models.CharField(max_length=30, blank=True)
    pickup_location = models.CharField(max_length=255, blank=True)
    destination_location = models.CharField(max_length=255, blank=True)
    passenger_count = models.PositiveSmallIntegerField(default=1)
    notes = models.TextField(blank=True)
    photo = models.ImageField(upload_to=passenger_photo_upload_path, null=True, blank=True)

    trip_pin = models.CharField(max_length=4, editable=False, blank=True)
    auto_check_in = models.BooleanField(default=False)

    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default="active")
    logged_at = models.DateTimeField(auto_now_add=True)
    dropped_off_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-logged_at"]

    def __str__(self):
        return f"{self.passenger_name} · PIN {self.trip_pin} ({self.get_status_display()})"

    def save(self, *args, **kwargs):
        if not self.trip_pin:
            self.trip_pin = str(random.randint(1000, 9999))
        super().save(*args, **kwargs)


class EhailingPanicAlert(models.Model):
    """
    One model for both the passenger panic button and the driver panic
    button (ehailing_page.dart has two separate UIs for this but they
    do the same thing: notify + attach whatever context is active).
    Uses the same response-window pattern as emergencies.EmergencyReport
    so the dashboard treats both kinds of panic consistently.
    """

    ROLE_CHOICES = [
        ("passenger", "Passenger"),
        ("driver", "Driver"),
    ]

    STATUS_CHOICES = [
        ("active", "Active"),
        ("responding", "Responding"),
        ("resolved", "Resolved"),
        ("unresponded", "Unresponded"),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="ehailing_panic_alerts")
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)

    trip = models.ForeignKey(Trip, null=True, blank=True, on_delete=models.SET_NULL, related_name="panic_alerts")
    passenger_log = models.ForeignKey(PassengerLog, null=True, blank=True, on_delete=models.SET_NULL, related_name="panic_alerts")
    community = models.ForeignKey(DriverCommunity, null=True, blank=True, on_delete=models.SET_NULL, related_name="panic_alerts")

    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)

    status = models.CharField(max_length=15, choices=STATUS_CHOICES, default="active")
    responded_at = models.DateTimeField(null=True, blank=True)
    response_notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.get_role_display()} panic · {self.get_status_display()}"

    @property
    def response_deadline(self):
        return self.created_at + timezone.timedelta(minutes=RESPONSE_WINDOW_MINUTES)

    @property
    def is_overdue(self):
        if self.responded_at or self.status in ("resolved", "unresponded"):
            return False
        return timezone.now() > self.response_deadline