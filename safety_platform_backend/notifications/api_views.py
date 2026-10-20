from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from .models import Notification
from .serializers import NotificationSerializer


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def notification_list(request):
    # Someone who listed you as an emergency contact may have just gone
    # overdue. Nothing runs on a clock, so check here (the app polls this
    # endpoint every few seconds) and create the alert straight away.
    try:
        from activity_log.overdue import notify_overdue_for_contact

        notify_overdue_for_contact(request.user)
    except Exception:
        pass  # never let this break the notifications list

    notifications = Notification.objects.filter(user=request.user)[:50]
    return Response(NotificationSerializer(notifications, many=True).data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def mark_all_read(request):
    Notification.objects.filter(user=request.user, read=False).update(read=True)
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def mark_one_read(request, pk):
    Notification.objects.filter(user=request.user, pk=pk).update(read=True)
    return Response(status=status.HTTP_204_NO_CONTENT)