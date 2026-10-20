from django.contrib.auth import get_user_model
from django.db.models.signals import m2m_changed, post_save
from django.dispatch import receiver

from chat.models import Message
from community.models import PostComment, PostReaction, PostShare
from emergencies.models import EmergencyReport
from news.models import NewsPost

from .models import Notification


@receiver(post_save, sender=EmergencyReport)
def notify_on_emergency_response(sender, instance, created, **kwargs):
    """Notifies the reporter the first time an admin responds, and only once."""
    if created or not instance.responded_at or not instance.user:
        return
    already = Notification.objects.filter(
        user=instance.user, type="report", message__icontains=instance.reference
    ).exists()
    if not already:
        Notification.notify(
            instance.user,
            "report",
            f"An admin has responded to your {instance.get_incident_type_display()} alert ({instance.reference}).",
            action="open_emergency",
        )


@receiver(m2m_changed, sender=EmergencyReport.notified_contacts.through)
def notify_contacts_on_emergency(sender, instance, action, pk_set, **kwargs):
    """Fires when trigger_emergency() attaches matched contacts to an alert."""
    if action != "post_add" or not pk_set:
        return
    User = get_user_model()
    reporter_name = instance.user.full_name if instance.user else "Someone"
    for user in User.objects.filter(id__in=pk_set):
        Notification.notify(
            user,
            "alert",
            f"{reporter_name} (your emergency contact) triggered a {instance.get_incident_type_display()} alert.",
            action="open_emergency",
        )


@receiver(post_save, sender=NewsPost)
def notify_all_on_news_post(sender, instance, created, **kwargs):
    if not created:
        return
    User = get_user_model()
    Notification.notify_many(
        User.objects.exclude(id=instance.posted_by_id or -1),
        "alert" if instance.category == "alert" else "system",
        f"New {instance.get_category_display()}: {instance.title}",
    )


@receiver(post_save, sender=PostReaction)
def notify_on_post_like(sender, instance, created, **kwargs):
    if not created:
        return
    post = instance.post
    if not post.author or post.author_id == instance.user_id:
        return
    liker = instance.user.full_name if instance.user else "Someone"
    Notification.notify(post.author, "community", f"{liker} liked your post.", action="community_post", object_id=post.id)


@receiver(post_save, sender=PostComment)
def notify_on_post_comment(sender, instance, created, **kwargs):
    if not created:
        return
    post = instance.post
    if not post.author or (instance.author_id and post.author_id == instance.author_id):
        return
    commenter = instance.author.full_name if instance.author else "Someone"
    Notification.notify(post.author, "community", f"{commenter} commented on your post.", action="community_post", object_id=post.id)


@receiver(post_save, sender=PostShare)
def notify_on_post_share(sender, instance, created, **kwargs):
    if not created:
        return
    post = instance.post
    if not post.author or (instance.user_id and post.author_id == instance.user_id):
        return
    sharer = instance.user.full_name if instance.user else "Someone"
    Notification.notify(post.author, "community", f"{sharer} shared your post.", action="community_post", object_id=post.id)


@receiver(post_save, sender=Message)
def notify_on_chat_message(sender, instance, created, **kwargs):
    """Everyone else in the conversation gets a bell notification for a new message."""
    if not created or not instance.sender_id:
        return
    conversation = instance.conversation
    sender_name = instance.sender.full_name or instance.sender.email
    preview = (instance.text or "").strip().replace("\n", " ")
    if "google.com/maps/search" in preview:
        preview = "📍 shared a location"
    elif len(preview) > 80:
        preview = preview[:79] + "…"
    body = f"{sender_name}: {preview}" if preview else f"{sender_name} sent you a message"
    if conversation.is_group and conversation.name:
        body = f"{conversation.name} · {body}"
    for user in conversation.members.exclude(id=instance.sender_id):
        # Replace the older unread one from this conversation: a tidy list, but still a new item (new sound).
        Notification.objects.filter(user=user, action="chat_message", object_id=conversation.id, read=False).delete()
        Notification.notify(user, "message", body, action="chat_message", object_id=conversation.id)