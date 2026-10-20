from django.conf import settings
from django.db import models

def message_media_upload_path(instance, filename):
    return f"chat_media/{instance.message_id or 'new'}/{filename}"


class Conversation(models.Model):
    """
    Backs the Messages sheet in header.dart. A 1:1 chat is just a
    Conversation with exactly two ConversationMembership rows and
    is_group=False; a group chat is the same model with is_group=True
    and a name. Keeping both on one model means the Flutter side can
    treat every chat the same way (one list, one message thread UI)
    instead of branching between two different types.
    """

    is_group = models.BooleanField(default=False)
    name = models.CharField(max_length=150, blank=True)  # only meaningful for groups
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="conversations_created")
    members = models.ManyToManyField(settings.AUTH_USER_MODEL, through="ConversationMembership", related_name="conversations")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)  # bumped whenever a message is sent, drives list ordering

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return self.name or f"Conversation {self.pk}"

    def display_name_for(self, user):
        if self.is_group:
            return self.name or "Group Chat"
        other = self.members.exclude(id=user.id).first()
        return other.full_name if other and other.full_name else (other.email if other else "Unknown")

    def other_member_for(self, user):
        if self.is_group:
            return None
        return self.members.exclude(id=user.id).first()


class ConversationMembership(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="chat_memberships")
    joined_at = models.DateTimeField(auto_now_add=True)
    # Bumped every time this user marks the conversation read — unread
    # count is computed as "messages after this", never a running
    # counter that could drift out of sync.
    last_read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ("conversation", "user")


class Message(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="chat_messages")
    text = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"{self.sender}: {self.text[:30]}"

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        super().save(*args, **kwargs)
        if is_new:
            Conversation.objects.filter(pk=self.conversation_id).update(updated_at=self.created_at)


class MessageMedia(models.Model):
    message = models.ForeignKey(Message, on_delete=models.CASCADE, related_name="media")
    file = models.FileField(upload_to=message_media_upload_path)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    @property
    def media_type(self):
        name = self.file.name.lower()
        if name.endswith((".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic")):
            return "image"
        if name.endswith((".mp4", ".mov", ".avi", ".mkv", ".m4v", ".3gp", ".webm")):
            return "video"
        if name.endswith((".m4a", ".aac", ".mp3", ".wav", ".ogg", ".opus", ".amr")):
            return "audio"
        return "file"