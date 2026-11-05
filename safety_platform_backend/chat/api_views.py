from django.contrib.auth import get_user_model
from django.db.models import Prefetch, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, serializers, status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from accounts.reactions import apply_reaction, clean_emoji, summarize

from .models import Conversation, ConversationMembership, Message, MessageMedia, MessageReaction
from .serializers import ConversationSerializer, MessageSerializer

User = get_user_model()

MAX_ICON_BYTES = 5 * 1024 * 1024  # 5MB
MAX_STICKER_LENGTH = 32


def _photo_url(user, request):
    if not user.profile_photo:
        return None
    return request.build_absolute_uri(user.profile_photo.url)


def _messages_queryset(conversation):
    """Messages with their media and reactions loaded in one go (no per-message queries)."""
    return (
        conversation.messages.select_related("sender")
        .prefetch_related(
            "media",
            Prefetch("reactions", queryset=MessageReaction.objects.select_related("user")),
        )
    )


def _conversation_context(request):
    return {"request": request}


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def search_users(request):
    # For "start a new chat" / "add to group" pickers.
    q = request.GET.get("q", "").strip()
    if not q:
        return Response([])
    users = User.objects.filter(Q(full_name__icontains=q) | Q(email__icontains=q)).exclude(id=request.user.id)[:20]
    return Response(
        [
            {"id": u.id, "name": u.full_name or u.email, "email": u.email, "photo_url": _photo_url(u, request)}
            for u in users
        ]
    )


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def conversation_list_create(request):
    if request.method == "GET":
        conversations = Conversation.objects.filter(members=request.user).distinct().prefetch_related("members")
        return Response(ConversationSerializer(conversations, many=True, context=_conversation_context(request)).data)

    member_ids = request.data.get("member_ids") or []
    is_group = bool(request.data.get("is_group"))
    name = (request.data.get("name") or "").strip()

    if not member_ids:
        return Response({"member_ids": ["At least one other member is required."]}, status=status.HTTP_400_BAD_REQUEST)

    member_ids = set(int(m) for m in member_ids)
    member_ids.add(request.user.id)

    if not is_group and len(member_ids) == 2:
        # Reuse an existing 1:1 conversation instead of creating a
        # duplicate thread every time the same two people "start" a chat.
        other_id = next(iter(member_ids - {request.user.id}))
        existing = (
            Conversation.objects.filter(is_group=False, members=request.user)
            .filter(members=other_id)
            .distinct()
            .first()
        )
        if existing:
            return Response(ConversationSerializer(existing, context=_conversation_context(request)).data)

    conversation = Conversation.objects.create(is_group=is_group, name=name if is_group else "", created_by=request.user)
    for uid in member_ids:
        ConversationMembership.objects.create(conversation=conversation, user_id=uid)

    return Response(ConversationSerializer(conversation, context=_conversation_context(request)).data, status=status.HTTP_201_CREATED)


def _ensure_member(request, conversation):
    return conversation.members.filter(id=request.user.id).exists()


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def message_list_create(request, pk):
    conversation = get_object_or_404(Conversation, pk=pk)
    if not _ensure_member(request, conversation):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        messages = _messages_queryset(conversation)
        after_id = request.GET.get("after_id")
        if after_id:
            messages = messages.filter(id__gt=after_id)
        return Response(MessageSerializer(messages, many=True, context={"request": request}).data)

    text = (request.data.get("text") or "").strip()
    sticker = (request.data.get("sticker") or "").strip()
    files = request.FILES.getlist("media")

    if sticker and (len(sticker) > MAX_STICKER_LENGTH or any(ch in sticker for ch in "\r\n\t")):
        return Response({"detail": "That sticker is not valid."}, status=status.HTTP_400_BAD_REQUEST)
    if not text and not files and not sticker:
        return Response({"detail": "A message needs text, a sticker or media."}, status=status.HTTP_400_BAD_REQUEST)

    message = Message.objects.create(conversation=conversation, sender=request.user, text=text, sticker=sticker)
    for f in files:
        MessageMedia.objects.create(message=message, file=f)

    message = _messages_queryset(conversation).get(pk=message.pk)
    return Response(MessageSerializer(message, context={"request": request}).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def mark_read(request, pk):
    conversation = get_object_or_404(Conversation, pk=pk)
    if not _ensure_member(request, conversation):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    membership = conversation.memberships.filter(user=request.user).first()
    if membership:
        membership.last_read_at = timezone.now()
        membership.save()
    return Response(status=status.HTTP_204_NO_CONTENT)


class _IconSerializer(serializers.Serializer):
    # ImageField checks that the upload really is a picture (needs Pillow).
    icon = serializers.ImageField()

    def validate_icon(self, value):
        if value.size > MAX_ICON_BYTES:
            raise serializers.ValidationError("That picture is too large. Please choose one under 5MB.")
        return value


@api_view(["POST", "DELETE"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def conversation_icon(request, pk):
    """
    POST   multipart with a file field named 'icon' -> sets the group picture.
    DELETE -> removes it (the app goes back to the default group icon).
    Any member of the group can change it. One-to-one chats have no group icon.
    """
    conversation = get_object_or_404(Conversation, pk=pk)
    if not _ensure_member(request, conversation):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
    if not conversation.is_group:
        return Response(
            {"detail": "Only group chats have a group picture."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if request.method == "DELETE":
        if conversation.icon:
            conversation.icon.delete(save=False)
        conversation.icon = None
        conversation.save(update_fields=["icon"])
    else:
        upload = request.FILES.get("icon")
        if upload is None:
            return Response({"detail": "No picture was sent."}, status=status.HTTP_400_BAD_REQUEST)
        serializer = _IconSerializer(data={"icon": upload})
        serializer.is_valid(raise_exception=True)
        if conversation.icon:
            conversation.icon.delete(save=False)
        conversation.icon = serializer.validated_data["icon"]
        conversation.save(update_fields=["icon"])

    conversation = Conversation.objects.prefetch_related("members").get(pk=conversation.pk)
    return Response(ConversationSerializer(conversation, context=_conversation_context(request)).data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([JSONParser, FormParser, MultiPartParser])
def message_react(request, pk):
    """
    Body: {"emoji": "👍"}. Sending the same emoji again removes it, a different
    one replaces it, and an empty emoji removes your reaction.
    """
    message = get_object_or_404(Message.objects.select_related("conversation"), pk=pk)
    if not _ensure_member(request, message.conversation):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    emoji = clean_emoji(request.data.get("emoji"))
    if emoji is None:
        return Response({"detail": "Please choose an emoji."}, status=status.HTTP_400_BAD_REQUEST)

    apply_reaction(MessageReaction, {"message": message}, request.user, emoji)

    reactions = MessageReaction.objects.filter(message=message).select_related("user")
    return Response({"message_id": message.pk, "reactions": summarize(reactions, request.user.id, request)})


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def conversation_reactions(request, pk):
    """
    {"<message id>": [reactions...]} for the latest messages that have any.
    The app asks for this every few seconds so reactions on older messages
    update without reloading the whole chat.
    """
    conversation = get_object_or_404(Conversation, pk=pk)
    if not _ensure_member(request, conversation):
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    recent_ids = list(conversation.messages.order_by("-id").values_list("id", flat=True)[:200])
    rows = MessageReaction.objects.filter(message_id__in=recent_ids).select_related("user")
    grouped = {}
    for r in rows:
        grouped.setdefault(r.message_id, []).append(r)
    return Response({str(mid): summarize(rs, request.user.id, request) for mid, rs in grouped.items()})