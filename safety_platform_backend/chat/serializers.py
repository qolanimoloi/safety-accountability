from rest_framework import serializers

from accounts.reactions import summarize

from .models import Conversation, Message, MessageMedia


def _photo_url(user, request):
    """Full https:// address of a person's profile picture, or None."""
    photo = getattr(user, "profile_photo", None) if user else None
    if not photo:
        return None
    url = photo.url
    return request.build_absolute_uri(url) if request else url


class MessageMediaSerializer(serializers.ModelSerializer):
    media_type = serializers.CharField(read_only=True)
    url = serializers.SerializerMethodField()

    class Meta:
        model = MessageMedia
        fields = ["id", "url", "media_type"]

    def get_url(self, obj):
        request = self.context.get("request")
        url = obj.file.url
        return request.build_absolute_uri(url) if request else url


class MessageSerializer(serializers.ModelSerializer):
    media = MessageMediaSerializer(many=True, read_only=True)
    sender_id = serializers.IntegerField(source="sender.id", read_only=True)
    sender_name = serializers.SerializerMethodField()
    sender_photo = serializers.SerializerMethodField()
    is_mine = serializers.SerializerMethodField()
    reactions = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            "id", "conversation", "sender_id", "sender_name", "sender_photo", "is_mine",
            "text", "sticker", "media", "reactions", "created_at",
        ]
        read_only_fields = fields

    def get_sender_name(self, obj):
        if not obj.sender:
            return "Unknown"
        return obj.sender.full_name or obj.sender.email

    def get_sender_photo(self, obj):
        return _photo_url(obj.sender, self.context.get("request"))

    def get_is_mine(self, obj):
        request = self.context.get("request")
        return bool(request and obj.sender_id == request.user.id)

    def get_reactions(self, obj):
        request = self.context.get("request")
        user_id = request.user.id if request else None
        return summarize(obj.reactions.all(), user_id, request)


class ConversationSerializer(serializers.ModelSerializer):
    display_name = serializers.SerializerMethodField()
    avatar_initials = serializers.SerializerMethodField()
    icon_url = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    member_count = serializers.SerializerMethodField()
    other_member_id = serializers.SerializerMethodField()
    members = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            "id", "is_group", "name", "display_name", "avatar_initials", "icon_url", "avatar_url",
            "last_message", "unread_count", "member_count", "other_member_id", "members", "updated_at",
        ]
        read_only_fields = fields

    def _request(self):
        return self.context.get("request")

    def _request_user(self):
        request = self._request()
        return request.user if request else None

    def get_display_name(self, obj):
        user = self._request_user()
        return obj.display_name_for(user) if user else (obj.name or "Conversation")

    def get_avatar_initials(self, obj):
        name = self.get_display_name(obj).strip()
        parts = [p for p in name.split() if p]
        if not parts:
            return "?"
        if len(parts) == 1:
            return parts[0][0].upper()
        return (parts[0][0] + parts[1][0]).upper()

    def get_icon_url(self, obj):
        if not obj.icon:
            return None
        url = obj.icon.url
        request = self._request()
        return request.build_absolute_uri(url) if request else url

    def get_avatar_url(self, obj):
        """The picture to show in the chat list: group icon, or the other person's profile picture."""
        if obj.is_group:
            return self.get_icon_url(obj)
        user = self._request_user()
        other = obj.other_member_for(user) if user else None
        return _photo_url(other, self._request())

    def get_last_message(self, obj):
        last = obj.messages.order_by("-created_at").first()
        if not last:
            return None
        text = (last.text or "").strip()
        if "google.com/maps/search" in text:
            return "📍 Location"
        if text:
            return text
        if last.sticker:
            return "💬 Sticker"
        media = last.media.first()
        if not media:
            return ""
        return {"image": "📷 Photo", "video": "🎥 Video", "audio": "🎤 Voice message"}.get(media.media_type, "📎 File")

    def get_unread_count(self, obj):
        user = self._request_user()
        if not user:
            return 0
        membership = obj.memberships.filter(user=user).first()
        if not membership:
            return 0
        qs = obj.messages.exclude(sender=user)
        if membership.last_read_at:
            qs = qs.filter(created_at__gt=membership.last_read_at)
        return qs.count()

    def get_member_count(self, obj):
        return obj.members.count()

    def get_other_member_id(self, obj):
        user = self._request_user()
        if obj.is_group or not user:
            return None
        other = obj.other_member_for(user)
        return other.id if other else None

    def get_members(self, obj):
        request = self._request()
        return [
            {
                "id": m.id,
                "name": m.full_name or m.email,
                "photo_url": _photo_url(m, request),
            }
            for m in obj.members.all()
        ]