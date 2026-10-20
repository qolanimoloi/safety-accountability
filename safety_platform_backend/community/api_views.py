from django.shortcuts import get_object_or_404
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from .models import CommunityPost, PostReaction, PostShare
from .serializers import (
    CommunityPostCreateSerializer,
    CommunityPostSerializer,
    PostCommentCreateSerializer,
    PostCommentSerializer,
    PostReportCreateSerializer,
)


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def post_list_create(request):
    if request.method == "GET":
        posts = CommunityPost.objects.filter(status="published").select_related("author")

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


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def comment_list_create(request, pk):
    post = get_object_or_404(CommunityPost, pk=pk, status="published")

    if request.method == "GET":
        return Response(PostCommentSerializer(post.comments.select_related("author"), many=True).data)

    serializer = PostCommentCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    comment = serializer.save(post=post, author=request.user)
    return Response(PostCommentSerializer(comment).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def share_post(request, pk):
    post = get_object_or_404(CommunityPost, pk=pk, status="published")
    PostShare.objects.create(post=post, user=request.user)
    return Response({"shares_count": post.shares_count})


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