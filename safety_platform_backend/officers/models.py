from django.conf import settings
from django.db import models


class Officer(models.Model):
    """
    Registered police / private security / campus security personnel
    who can be assigned to respond to an emergency. Strictly an
    admin-managed record — officers don't log into the app themselves;
    the admin registers them here and clocks them on/off duty.
    """

    ORGANIZATION_TYPE_CHOICES = [
        ("police", "Police"),
        ("private_security", "Private Security"),
        ("campus_security", "Campus Security"),
    ]

    full_name = models.CharField(max_length=150)
    badge_number = models.CharField(max_length=50, unique=True)
    phone_number = models.CharField(max_length=30, blank=True)
    email = models.EmailField(blank=True)
    organization_type = models.CharField(max_length=20, choices=ORGANIZATION_TYPE_CHOICES)
    organization_name = models.CharField(max_length=150, blank=True)

    is_on_duty = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)  # still on the roster vs removed

    registered_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="officers_registered")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["full_name"]

    def __str__(self):
        return f"{self.full_name} ({self.badge_number})"


class OfficerDutyLog(models.Model):
    """
    Audit trail every time an officer is clocked on or off duty, and by
    which admin — a record, not just the current flag on Officer.
    """

    officer = models.ForeignKey(Officer, related_name="duty_logs", on_delete=models.CASCADE)
    is_on_duty = models.BooleanField()
    changed_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="duty_changes_made")
    changed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-changed_at"]

    def __str__(self):
        return f"{self.officer.full_name} -> {'On Duty' if self.is_on_duty else 'Off Duty'}"