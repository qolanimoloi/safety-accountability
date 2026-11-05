"""
Helpers behind the Share button: send a community post into chats,
or to a person's accepted emergency contacts.
"""
from chat.models import Conversation, ConversationMembership, Message, MessageMedia

MAX_QUOTE_LENGTH = 300


def usable_original(post):
    """The post that should actually be shared: for a repost, the original it points at."""
    if post.is_repost:
        original = post.shared_from
        if original is None or original.status != "published":
            return None
        return original
    return post


def share_text(post):
    source = usable_original(post) or post
    author = source.author.full_name if source.author and source.author.full_name else "a community member"
    lines = [f"📢 Community post by {author} ({source.get_category_display()})"]
    content = (source.content or "").strip()
    if content:
        if len(content) > MAX_QUOTE_LENGTH:
            content = content[:MAX_QUOTE_LENGTH].rstrip() + "…"
        lines.append(content)
    lines.append("Open the Community tab in the app to see the full post.")
    return "\n".join(lines)


def get_or_create_direct(user, other):
    """The existing 1:1 chat between two people, or a new one."""
    existing = (
        Conversation.objects.filter(is_group=False, members=user)
        .filter(members=other)
        .distinct()
        .first()
    )
    if existing:
        return existing
    conversation = Conversation.objects.create(is_group=False, created_by=user)
    ConversationMembership.objects.create(conversation=conversation, user=user)
    ConversationMembership.objects.create(conversation=conversation, user=other)
    return conversation


def send_post_to_conversation(user, conversation, post):
    """Posts the shared post as a chat message, with its first picture/video attached."""
    message = Message.objects.create(conversation=conversation, sender=user, text=share_text(post))
    source = usable_original(post) or post
    first = source.media.first()
    if first is not None:
        # Re-uses the stored file; nothing is copied or uploaded again.
        MessageMedia.objects.create(message=message, file=first.file.name)
    return message