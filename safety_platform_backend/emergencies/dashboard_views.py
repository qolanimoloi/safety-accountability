from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone

from .models import EmergencyReport


def _is_dashboard_admin(user):
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def emergency_list(request):
    emergencies = EmergencyReport.objects.select_related("user").all()

    status = request.GET.get("status", "")
    incident_type = request.GET.get("incident_type", "")

    if status:
        emergencies = emergencies.filter(status=status)
    if incident_type:
        emergencies = emergencies.filter(incident_type=incident_type)

    return render(
        request,
        "dashboard/emergencies/emergency_list.html",
        {
            "emergencies": emergencies,
            "status_choices": EmergencyReport.STATUS_CHOICES,
            "incident_type_choices": EmergencyReport.INCIDENT_TYPE_CHOICES,
            "selected_status": status,
            "selected_incident_type": incident_type,
        },
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def emergency_detail(request, pk):
    emergency = get_object_or_404(EmergencyReport, pk=pk)

    if request.method == "POST":
        action = request.POST.get("action")
        if action == "respond" and not emergency.responded_at:
            # The moment an admin clicks this is what the app's polling
            # endpoint checks to stop its countdown and skip PONR —
            # this is the real version of what the Flutter mock's timer
            # currently has nothing behind it to wait for.
            emergency.responded_at = timezone.now()
            emergency.status = "responding"
        emergency.response_notes = request.POST.get("response_notes", emergency.response_notes)
        if request.POST.get("status"):
            emergency.status = request.POST["status"]
        emergency.save()
        messages.success(request, f"Updated {emergency.reference}.")
        return redirect("dashboard:emergency_detail", pk=emergency.pk)

    return render(request, "dashboard/emergencies/emergency_detail.html", {"emergency": emergency})