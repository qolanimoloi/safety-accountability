from django.contrib.auth import get_user_model
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from .models import Conversation, ConversationMembership, Message, MessageMedia
from .serializers import ConversationSerializer, MessageSerializer

User = get_user_model()


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def search_users(request):
    # For "start a new chat" / "add to group" pickers.
    q = request.GET.get("q", "").strip()
    if not q:
        return Response([])
    users = User.objects.filter(Q(full_name__icontains=q) | Q(email__icontains=q)).exclude(id=request.user.id)[:20]
    return Response([{"id": u.id, "name": u.full_name or u.email, "email": u.email} for u in users])


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def conversation_list_create(request):
    if request.method == "GET":
        conversations = Conversation.objects.filter(members=request.user).distinct()
        return Response(ConversationSerializer(conversations, many=True, context={"request": request}).data)

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
            return Response(ConversationSerializer(existing, context={"request": request}).data)

    conversation = Conversation.objects.create(is_group=is_group, name=name if is_group else "", created_by=request.user)
    for uid in member_ids:
        ConversationMembership.objects.create(conversation=conversation, user_id=uid)

    return Response(ConversationSerializer(conversation, context={"request": request}).data, status=status.HTTP_201_CREATED)


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
        messages = conversation.messages.all()
        after_id = request.GET.get("after_id")
        if after_id:
            messages = messages.filter(id__gt=after_id)
        return Response(MessageSerializer(messages, many=True, context={"request": request}).data)

    text = (request.data.get("text") or "").strip()
    files = request.FILES.getlist("media")
    if not text and not files:
        return Response({"detail": "A message needs text or media."}, status=status.HTTP_400_BAD_REQUEST)

    message = Message.objects.create(conversation=conversation, sender=request.user, text=text)
    for f in files:
        MessageMedia.objects.create(message=message, file=f)

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