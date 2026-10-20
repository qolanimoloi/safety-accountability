from rest_framework import permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from .models import NewsPost
from .serializers import NewsPostSerializer
from .stats import compute_stats


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def news_list(request):
    posts = NewsPost.objects.all()
    return Response(NewsPostSerializer(posts, many=True).data)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def news_stats(request):
    return Response({
        "week": compute_stats(7),
        "month": compute_stats(30),
    })