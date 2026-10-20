from rest_framework import permissions, status
from rest_framework.decorators import (
    api_view,
    authentication_classes,
    parser_classes,
    permission_classes,
    throttle_classes,
)
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle
from .models import AnonymousReport
from .serializers import AnonymousReportSubmitSerializer, AnonymousReportTrackSerializer


@api_view(["POST"])
@authentication_classes([])  # anonymous: never read or require a token
@permission_classes([permissions.AllowAny])
@parser_classes([MultiPartParser, FormParser])
@throttle_classes([AnonRateThrottle])
def submit_report(request):
    # Pass request.data straight through. The serializer's ListField reads
    # every file sent under the repeated "evidence" key.
    serializer = AnonymousReportSubmitSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    report = serializer.save()
    return Response(
        {
            "tracking_code": report.tracking_code,
            "status": report.status,
            "message": "Report submitted successfully. Save your tracking code to check its status later.",
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET"])
@authentication_classes([])
@permission_classes([permissions.AllowAny])
@throttle_classes([AnonRateThrottle])
def track_report(request, tracking_code):
    try:
        report = AnonymousReport.objects.get(tracking_code=tracking_code)
    except AnonymousReport.DoesNotExist:
        return Response(
            {"detail": "No report found for that tracking code."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(
        AnonymousReportTrackSerializer(report, context={"request": request}).data
    )