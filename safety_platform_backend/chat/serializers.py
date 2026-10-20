from rest_framework import serializers
from .models import Conversation, Message, MessageMedia

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
    is_mine = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ["id", "conversation", "sender_id", "sender_name", "is_mine", "text", "media", "created_at"]
        read_only_fields = ["id", "conversation", "sender_id", "sender_name", "is_mine", "media", "created_at"]

    def get_sender_name(self, obj):
        if not obj.sender:
            return "Unknown"
        return obj.sender.full_name or obj.sender.email

    def get_is_mine(self, obj):
        request = self.context.get("request")
        return bool(request and obj.sender_id == request.user.id)


class ConversationSerializer(serializers.ModelSerializer):
    display_name = serializers.SerializerMethodField()
    avatar_initials = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    member_count = serializers.SerializerMethodField()
    other_member_id = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            "id", "is_group", "name", "display_name", "avatar_initials",
            "last_message", "unread_count", "member_count", "other_member_id", "updated_at",
        ]
        read_only_fields = fields

    def _request_user(self):
        request = self.context.get("request")
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

    def get_last_message(self, obj):
        last = obj.messages.order_by("-created_at").first()
        if not last:
            return None
        text = (last.text or "").strip()
        if "google.com/maps/search" in text:
            return "📍 Location"
        if text:
            return text
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