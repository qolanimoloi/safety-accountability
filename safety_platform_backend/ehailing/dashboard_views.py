from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.shortcuts import get_object_or_404, redirect, render
from django.utils import timezone
from .models import DriverCommunity, EhailingPanicAlert, PassengerLog, Trip


def _is_dashboard_admin(user):
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def panic_list(request):
    alerts = EhailingPanicAlert.objects.select_related("user", "trip", "passenger_log", "community")

    status = request.GET.get("status", "")
    role = request.GET.get("role", "")
    if status:
        alerts = alerts.filter(status=status)
    if role:
        alerts = alerts.filter(role=role)

    return render(
        request,
        "dashboard/ehailing/panic_list.html",
        {
            "alerts": alerts,
            "status_choices": EhailingPanicAlert.STATUS_CHOICES,
            "role_choices": EhailingPanicAlert.ROLE_CHOICES,
            "selected_status": status,
            "selected_role": role,
        },
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def panic_detail(request, pk):
    alert = get_object_or_404(EhailingPanicAlert, pk=pk)

    if request.method == "POST":
        action = request.POST.get("action")
        if action == "respond" and not alert.responded_at:
            alert.responded_at = timezone.now()
            alert.status = "responding"
            alert.save()
            messages.success(request, "Marked as responding.")
        elif action == "resolve":
            alert.status = "resolved"
            alert.response_notes = request.POST.get("response_notes", alert.response_notes)
            alert.save()
            messages.success(request, "Alert resolved.")
        return redirect("dashboard:ehailing_panic_detail", pk=alert.pk)

    return render(request, "dashboard/ehailing/panic_detail.html", {"alert": alert})


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def trip_list(request):
    trips = Trip.objects.select_related("passenger")
    status = request.GET.get("status", "")
    if status:
        trips = trips.filter(status=status)
    return render(
        request,
        "dashboard/ehailing/trip_list.html",
        {"trips": trips, "status_choices": Trip.STATUS_CHOICES, "selected_status": status},
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def passenger_log_list(request):
    logs = PassengerLog.objects.select_related("driver", "community")
    status = request.GET.get("status", "")
    if status:
        logs = logs.filter(status=status)
    return render(
        request,
        "dashboard/ehailing/passenger_log_list.html",
        {"logs": logs, "status_choices": PassengerLog.STATUS_CHOICES, "selected_status": status},
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def community_list(request):
    communities = DriverCommunity.objects.prefetch_related("members", "posts")
    return render(request, "dashboard/ehailing/community_list.html", {"communities": communities})


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def community_detail(request, pk):
    community = get_object_or_404(DriverCommunity, pk=pk)
    return render(
        request,
        "dashboard/ehailing/community_detail.html",
        {
            "community": community,
            "members": community.members.all(),
            "posts": community.posts.select_related("driver"),
            "passenger_logs": community.passenger_logs.select_related("driver"),
        },
    )