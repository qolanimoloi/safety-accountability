from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from .models import DriverCommunity, EhailingPanicAlert, PassengerLog, Trip
from .serializers import (
    DriverCommunityCreateSerializer,
    DriverCommunityPostCreateSerializer,
    DriverCommunityPostSerializer,
    DriverCommunitySerializer,
    EhailingPanicAlertSerializer,
    PassengerLogCreateSerializer,
    PassengerLogSerializer,
    TripCreateSerializer,
    TripSerializer,
)


# ---------------------------------------------------------------- Trips ----

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def trip_create(request):
    serializer = TripCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    trip = serializer.save(passenger=request.user)
    return Response(TripSerializer(trip).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def trip_end(request, pk):
    trip = get_object_or_404(Trip, pk=pk, passenger=request.user)
    trip.status = "ended"
    trip.ended_at = timezone.now()
    trip.save()
    return Response(TripSerializer(trip).data)


# ----------------------------------------------------- Driver communities --

@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def community_list_create(request):
    if request.method == "GET":
        communities = DriverCommunity.objects.all()
        return Response(
            DriverCommunitySerializer(communities, many=True, context={"request": request}).data
        )

    serializer = DriverCommunityCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    community = serializer.save(created_by=request.user)
    community.members.add(request.user)  # creator auto-joins, matching _createCommunity in the Flutter mock
    return Response(
        DriverCommunitySerializer(community, context={"request": request}).data,
        status=status.HTTP_201_CREATED,
    )


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def community_join(request, pk):
    community = get_object_or_404(DriverCommunity, pk=pk)
    community.members.add(request.user)
    return Response(DriverCommunitySerializer(community, context={"request": request}).data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def community_leave(request, pk):
    community = get_object_or_404(DriverCommunity, pk=pk)
    community.members.remove(request.user)
    return Response(DriverCommunitySerializer(community, context={"request": request}).data)


@api_view(["GET", "POST"])
@permission_classes([permissions.IsAuthenticated])
def community_post_list_create(request, pk):
    community = get_object_or_404(DriverCommunity, pk=pk)

    if request.method == "GET":
        posts = community.posts.select_related("driver")
        return Response(DriverCommunityPostSerializer(posts, many=True).data)

    if not community.members.filter(pk=request.user.pk).exists():
        return Response({"detail": "Join this community before posting."}, status=status.HTTP_403_FORBIDDEN)

    serializer = DriverCommunityPostCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    post = serializer.save(community=community, driver=request.user)
    return Response(DriverCommunityPostSerializer(post).data, status=status.HTTP_201_CREATED)


# --------------------------------------------------------- Passenger logs --

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def passenger_log_create(request):
    serializer = PassengerLogCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    # If the driver belongs to a community, attach the log to it — matches
    # the Flutter mock's "These details were shared with your driver community".
    community = request.user.ehailing_communities.first()

    log = serializer.save(driver=request.user, community=community)
    return Response(PassengerLogSerializer(log, context={"request": request}).data, status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def passenger_log_drop_off(request, pk):
    log = get_object_or_404(PassengerLog, pk=pk, driver=request.user)
    log.status = "completed"
    log.dropped_off_at = timezone.now()
    log.save()
    return Response(PassengerLogSerializer(log, context={"request": request}).data)


# --------------------------------------------------------------- Panic ----

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def panic_trigger(request):
    role = request.data.get("role")
    if role not in ("passenger", "driver"):
        return Response({"detail": "role must be 'passenger' or 'driver'."}, status=status.HTTP_400_BAD_REQUEST)

    trip = None
    passenger_log = None
    community = None

    trip_id = request.data.get("trip_id")
    if trip_id:
        trip = Trip.objects.filter(pk=trip_id, passenger=request.user, status="active").first()

    passenger_log_id = request.data.get("passenger_log_id")
    if passenger_log_id:
        passenger_log = PassengerLog.objects.filter(pk=passenger_log_id, driver=request.user, status="active").first()

    if role == "driver":
        community = request.user.ehailing_communities.first()

    alert = EhailingPanicAlert.objects.create(
        user=request.user,
        role=role,
        trip=trip,
        passenger_log=passenger_log,
        community=community,
        latitude=request.data.get("latitude"),
        longitude=request.data.get("longitude"),
    )
    return Response(EhailingPanicAlertSerializer(alert).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def panic_status(request, pk):
    alert = get_object_or_404(EhailingPanicAlert, pk=pk)
    # Same privacy rule as emergencies.emergency_status: only the person who
    # triggered it, or dashboard staff, can read it back.
    if alert.user_id != request.user.id and not (request.user.is_staff or request.user.is_dashboard_admin):
        return Response(status=status.HTTP_404_NOT_FOUND)
    return Response(EhailingPanicAlertSerializer(alert).data)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def panic_resolve(request, pk):
    alert = get_object_or_404(EhailingPanicAlert, pk=pk, user=request.user)
    alert.status = "resolved"
    alert.save()
    return Response(EhailingPanicAlertSerializer(alert).data)