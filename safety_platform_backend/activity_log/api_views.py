from django.shortcuts import get_object_or_404
from rest_framework import permissions, status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from emergencies.models import EmergencyContact

from .models import LoggedActivity
from .serializers import LoggedActivityCreateSerializer, LoggedActivitySerializer


def _data(activity, request):
    return LoggedActivitySerializer(activity, context={"request": request}).data


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def activity_list_create(request):
    if request.method == "GET":
        activities = LoggedActivity.objects.filter(user=request.user)
        return Response(LoggedActivitySerializer(activities, many=True, context={"request": request}).data)

    serializer = LoggedActivityCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    activity = serializer.save(user=request.user)
    return Response(_data(activity, request), status=status.HTTP_201_CREATED)


@api_view(["GET", "DELETE"])
@permission_classes([permissions.IsAuthenticated])
def activity_detail(request, pk):
    activity = get_object_or_404(LoggedActivity, pk=pk, user=request.user)

    if request.method == "DELETE":
        if activity.admin_is_open:
            return Response(
                {"detail": "This activity was sent to the admin team and is being handled. Tap \"I'm Safe\" instead."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        activity.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    return Response(_data(activity, request))


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def activity_mark_safe(request, pk):
    """
    Lets the person who logged the activity confirm they're back
    safely, moving it to completed. If a contact had already sent it
    to the admin team, that case is closed too.
    """
    activity = get_object_or_404(LoggedActivity, pk=pk, user=request.user)
    activity.status = "completed"
    if activity.admin_is_open:
        activity.set_admin_status("resolved", None, "The person marked themselves safe in the app.")
    else:
        activity.save()
    return Response(_data(activity, request))


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def shared_with_me(request):
    """
    Activities logged by anyone who has the current user saved as one
    of THEIR emergency contacts. The admin team does not see these
    unless a contact escalates one (see activity_escalate).
    """
    owner_ids = EmergencyContact.contacts_pointing_to(request.user).values_list("owner_id", flat=True)
    activities = LoggedActivity.objects.filter(user_id__in=owner_ids).exclude(status="cancelled")
    return Response(LoggedActivitySerializer(activities, many=True, context={"request": request}).data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def activity_escalate(request, pk):
    """
    An emergency contact sends an overdue activity to the admin team.
    Allowed only if: the caller has the activity's owner saved as one of
    the people who listed them as an emergency contact, and the person
    has not returned by their expected time.
    """
    activity = get_object_or_404(LoggedActivity, pk=pk)

    owner_ids = set(EmergencyContact.contacts_pointing_to(request.user).values_list("owner_id", flat=True))
    if activity.user_id is None or activity.user_id == request.user.id or activity.user_id not in owner_ids:
        return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    if activity.is_escalated:
        return Response(_data(activity, request))  # already sent, nothing more to do

    if not activity.can_escalate:
        return Response(
            {"detail": "This activity is not overdue yet, so it can't be sent to the admin team."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    activity.escalate(request.user, str(request.data.get("note") or ""))
    return Response(_data(activity, request))