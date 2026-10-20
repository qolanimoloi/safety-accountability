import logging

from django.apps import apps

logger = logging.getLogger(__name__)


def _notification_model():
    """Finds your Notification model wherever it lives, without caring which app owns it."""
    for model in apps.get_models():
        if model.__name__ == "Notification":
            return model
    return None


def send_notification(user, kind, message, action="", object_id=None):
    """Best effort: if anything is wrong, nothing happens and the request still succeeds."""
    if user is None:
        return
    model = _notification_model()
    if model is None:
        return
    try:
        if hasattr(model, "notify"):
            model.notify(user, kind, message, action=action, object_id=object_id)
        else:
            model.objects.create(user=user, type=kind, message=message[:255], action=action, object_id=object_id)
    except Exception:
        logger.exception("Could not create notification for user %s", getattr(user, "id", None))


def mark_handled(user, action, object_id):
    """Marks matching notifications as read once the person has dealt with them."""
    model = _notification_model()
    if model is None or user is None:
        return
    try:
        model.objects.filter(user=user, action=action, object_id=object_id, read=False).update(read=True)
    except Exception:
        logger.exception("Could not mark notifications handled")