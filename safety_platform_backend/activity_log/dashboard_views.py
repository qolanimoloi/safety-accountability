from functools import wraps

from django.contrib import messages
from django.contrib.auth.views import redirect_to_login
from django.db.models import Case, IntegerField, Q, When
from django.http import HttpResponseForbidden
from django.shortcuts import get_object_or_404, redirect, render

from emergencies.models import EmergencyContact

from .models import ADMIN_OPEN_STATUSES, ADMIN_STATUS_CHOICES, LoggedActivity


def _is_admin(user):
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


def admin_required(view):
    @wraps(view)
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            return redirect_to_login(request.get_full_path())
        if not _is_admin(request.user):
            return HttpResponseForbidden("You do not have access to the dashboard.")
        return view(request, *args, **kwargs)

    return wrapper


@admin_required
def activity_list(request):
    """Only activities that an emergency contact escalated. Nothing else reaches the admin."""
    state = request.GET.get("state", "open")
    q = request.GET.get("q", "").strip()

    base = LoggedActivity.objects.filter(escalated_at__isnull=False).select_related("user", "escalated_by")
    activities = base
    if state == "open":
        activities = activities.filter(admin_status__in=ADMIN_OPEN_STATUSES)
    elif state == "closed":
        activities = activities.exclude(admin_status__in=ADMIN_OPEN_STATUSES)
    if q:
        activities = activities.filter(
            Q(user__full_name__icontains=q)
            | Q(user__email__icontains=q)
            | Q(location__icontains=q)
            | Q(person_name__icontains=q)
        )

    new_first = Case(When(admin_status="new", then=0), default=1, output_field=IntegerField())
    open_qs = base.filter(admin_status__in=ADMIN_OPEN_STATUSES)
    context = {
        "activities": list(activities.annotate(rank=new_first).order_by("rank", "-escalated_at")[:300]),
        "state": state,
        "q": q,
        "open_total": open_qs.count(),
        "new_total": open_qs.filter(admin_status="new").count(),
        "authorities_total": open_qs.filter(admin_status="authorities").count(),
        "closed_total": base.exclude(admin_status__in=ADMIN_OPEN_STATUSES).count(),
    }
    return render(request, "dashboard/activity_log/activity_list.html", context)


@admin_required
def activity_detail(request, pk):
    activity = get_object_or_404(
        LoggedActivity.objects.select_related("user", "escalated_by", "admin_handled_by"),
        pk=pk,
        escalated_at__isnull=False,  # an activity nobody escalated is never shown to admins
    )

    if request.method == "POST":
        new_status = request.POST.get("status", "")
        notes = request.POST.get("notes", "").strip()
        if new_status in dict(ADMIN_STATUS_CHOICES) and new_status != "new":
            activity.set_admin_status(new_status, request.user, notes)
            messages.success(request, f"Marked as {activity.get_admin_status_display().lower()}.")
        elif notes:
            activity.add_admin_note(notes)
            activity.save()
            messages.success(request, "Note added.")
        return redirect("dashboard:activity_detail", pk=pk)

    contacts = EmergencyContact.objects.filter(owner=activity.user) if activity.user_id else []
    return render(
        request,
        "dashboard/activity_log/activity_detail.html",
        {"activity": activity, "contacts": contacts},
    )