from django.conf import settings
from django.db import models


class Notification(models.Model):
    TYPE_CHOICES = [
        ("alert", "Alert"),         # admin alerts, emergency alerts, contact requests
        ("message", "Message"),     # new chat messages
        ("report", "Report"),       # your own emergency/report status changing
        ("community", "Community"), # likes/comments/shares on your post
        ("system", "System"),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications")
    type = models.CharField(max_length=20, choices=TYPE_CHOICES, default="system")
    message = models.CharField(max_length=255)
    read = models.BooleanField(default=False)

    # Where tapping the notification takes the person. The app decides what to open:
    # contact_request, contact_response, chat_message, community_post, open_emergency.
    action = models.CharField(max_length=30, blank=True, default="")
    object_id = models.PositiveIntegerField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.user}: {self.message}"

    @classmethod
    def notify(cls, user, type, message, action="", object_id=None):
        if not user:
            return None
        return cls.objects.create(user=user, type=type, message=message[:255], action=action, object_id=object_id)

    @classmethod
    def notify_many(cls, users, type, message, action="", object_id=None):
        cls.objects.bulk_create(
            [cls(user=u, type=type, message=message[:255], action=action, object_id=object_id) for u in users if u]
        )