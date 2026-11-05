from django.db import transaction
from django.db.models import Prefetch
from django.shortcuts import get_object_or_404
from rest_framework import permissions, status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from accounts.reactions import apply_reaction, clean_emoji, summarize
from chat.models import Conversation
from emergencies.models import EmergencyContact

from .models import CommentReaction, CommunityPost, PostComment, PostReaction, PostShare
from .serializers import (
    CommunityPostCreateSerializer,
    CommunityPostSerializer,
    PostCommentCreateSerializer,
    PostCommentSerializer,
    PostReportCreateSerializer,
)
from .sharing import get_or_create_direct, send_post_to_conversation, usable_original

MAX_SHARE_CHATS = 10


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def post_list_create(request):
    if request.method == "GET":
        posts = CommunityPost.objects.filter(status="published").select_related("author", "shared_from__author")

        post_type = request.query_params.get("type")
        if post_type == "nearby":
            lat, lng = request.query_params.get("lat"), request.query_params.get("lng")
            posts = [p for p in posts if (p.distance_km_from(lat, lng) or 999) < 10]
        elif post_type == "viral":
            posts = [p for p in posts if p.is_trending]
        elif post_type in ("alert", "wanted", "warning"):
            posts = posts.filter(post_type=post_type)

        serializer = CommunityPostSerializer(posts, many=True, context={"request": request})
        return Response(serializer.data)

    # POST — create a post. is_official is never taken from client input
    # (CommunityPostCreateSerializer doesn't expose that field at all);
    # it's set here, server-side, from who's actually logged in.
    data = request.data.copy()
    data.setlist("media", request.FILES.getlist("media"))
    serializer = CommunityPostCreateSerializer(data=data)
    serializer.is_valid(raise_exception=True)
    post = serializer.save(
        author=request.user,
        is_official=bool(request.user.is_dashboard_admin or request.user.is_superuser),
    )
    return Response(CommunityPostSerializer(post, context={"request": request}).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def toggle_like(request, pk):
    post = get_object_or_404(CommunityPost, pk=pk, status="published")
    reaction, created = PostReaction.objects.get_or_create(post=post, user=request.user)
    if not created:
        reaction.delete()
        liked = False
    else:
        liked = True
    return Response({"liked": liked, "likes_count": post.likes_count})


def _comments_queryset(post):
    return post.comments.select_related("author").prefetch_related(
        Prefetch("reactions", queryset=CommentReaction.objects.select_related("user"))
    )


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def comment_list_create(request, pk):
    post = get_object_or_404(CommunityPost, pk=pk, status="published")
    context = {"request": request}

    if request.method == "GET":
        return Response(PostCommentSerializer(_comments_queryset(post), many=True, context=context).data)

    serializer = PostCommentCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    comment = serializer.save(post=post, author=request.user)
    comment = _comments_queryset(post).get(pk=comment.pk)
    return Response(PostCommentSerializer(comment, context=context).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([JSONParser, FormParser, MultiPartParser])
def comment_react(request, pk):
    """
    Body: {"emoji": "👍"}. Same emoji again removes it, a different one
    replaces it, an empty emoji removes your reaction.
    """
    comment = get_object_or_404(PostComment.objects.select_related("post"), pk=pk, post__status="published")

    emoji = clean_emoji(request.data.get("emoji"))
    if emoji is None:
        return Response({"detail": "Please choose an emoji."}, status=status.HTTP_400_BAD_REQUEST)

    apply_reaction(CommentReaction, {"comment": comment}, request.user, emoji)

    rows = CommentReaction.objects.filter(comment=comment).select_related("user")
    return Response({"comment_id": comment.pk, "reactions": summarize(rows, request.user.id, request)})


# --------------------------------------------------
# SHARE: community repost / chat / emergency contacts
# --------------------------------------------------

def _int_list(value):
    if not isinstance(value, (list, tuple)):
        return None
    try:
        return [int(v) for v in value]
    except (TypeError, ValueError):
        return None


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([JSONParser, FormParser, MultiPartParser])
def share_post(request, pk):
    """
    Body {"target": ...}:
      "community"  + optional "comment"  -> reposts it on the Community feed
      "chat"       + "conversation_ids"  -> sends it into those chats
      "contacts"                         -> sends it to your accepted emergency contacts who use the app
    No target: just counts a share (older app versions).
    """
    post = get_object_or_404(CommunityPost, pk=pk, status="published")
    target = str(request.data.get("target") or "").strip().lower()
    user = request.user

    if target == "":
        PostShare.objects.create(post=post, user=user)
        return Response({"shares_count": post.shares_count})

    if target == "community":
        original = usable_original(post)
        if original is None:
            return Response(
                {"detail": "The original post is no longer available."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        comment = str(request.data.get("comment") or "").strip()[:2000]
        with transaction.atomic():
            repost = CommunityPost.objects.create(
                author=user,
                post_type=original.post_type,
                category=original.category,
                content=comment,
                is_repost=True,
                shared_from=original,
                is_official=bool(user.is_dashboard_admin or user.is_superuser),
            )
            PostShare.objects.create(post=post, user=user)
            if original.pk != post.pk:
                PostShare.objects.create(post=original, user=user)
        return Response(
            {
                "shares_count": post.shares_count,
                "post": CommunityPostSerializer(repost, context={"request": request}).data,
            },
            status=status.HTTP_201_CREATED,
        )

    if target == "chat":
        ids = _int_list(request.data.get("conversation_ids"))
        if not ids:
            return Response({"detail": "Choose at least one chat."}, status=status.HTTP_400_BAD_REQUEST)
        if len(ids) > MAX_SHARE_CHATS:
            return Response(
                {"detail": f"You can send to up to {MAX_SHARE_CHATS} chats at once."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        conversations = list(Conversation.objects.filter(pk__in=set(ids), members=user).distinct())
        if not conversations:
            return Response({"detail": "Those chats could not be found."}, status=status.HTTP_404_NOT_FOUND)
        for conversation in conversations:
            send_post_to_conversation(user, conversation, post)
        PostShare.objects.create(post=post, user=user)
        return Response({"sent_to": len(conversations), "shares_count": post.shares_count})

    if target == "contacts":
        contacts = list(EmergencyContact.objects.filter(owner=user, status="accepted"))
        if not contacts:
            return Response(
                {"detail": "You have no accepted emergency contacts yet."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        sent, without_app, done = 0, [], set()
        for contact in contacts:
            other = contact.linked_user
            if other is None or other.pk == user.pk:
                without_app.append(contact.name)
                continue
            if other.pk in done:
                continue
            done.add(other.pk)
            send_post_to_conversation(user, get_or_create_direct(user, other), post)
            sent += 1
        if sent:
            PostShare.objects.create(post=post, user=user)
        return Response({"sent_to": sent, "without_app": without_app, "shares_count": post.shares_count})

    return Response({"detail": "Unknown share option."}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def report_post(request, pk):
    post = get_object_or_404(CommunityPost, pk=pk)
    serializer = PostReportCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    serializer.save(post=post, reporter=request.user)
    return Response({"detail": "Report submitted. Our team will review this post."}, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def quick_alert(request):
    """
    The FAB in community_page.dart currently just shows a snackbar and
    does nothing real. This turns it into an actual one-tap post: a
    CommunityPost flagged is_quick_alert=True so the dashboard and feed
    can tell it apart from a composed post, defaulting to an urgent
    General Alert if the person doesn't type a message.
    """
    content = request.data.get("message", "").strip() or " Quick Alert triggered near this location."
    post = CommunityPost.objects.create(
        author=request.user,
        post_type="alert",
        category="general_alert",
        content=content,
        latitude=request.data.get("latitude"),
        longitude=request.data.get("longitude"),
        is_official=bool(request.user.is_dashboard_admin or request.user.is_superuser),
        is_quick_alert=True,
    )
    return Response(CommunityPostSerializer(post, context={"request": request}).data, status=status.HTTP_201_CREATED)