from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.shortcuts import get_object_or_404, redirect, render
from .models import Officer, OfficerDutyLog


def _is_dashboard_admin(user):
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def officer_list(request):
    officers = Officer.objects.filter(is_active=True)

    organization_type = request.GET.get("organization_type", "")
    duty_status = request.GET.get("duty_status", "")
    query = request.GET.get("q", "").strip()

    if organization_type:
        officers = officers.filter(organization_type=organization_type)
    if duty_status == "on":
        officers = officers.filter(is_on_duty=True)
    elif duty_status == "off":
        officers = officers.filter(is_on_duty=False)
    if query:
        officers = officers.filter(full_name__icontains=query) | officers.filter(badge_number__icontains=query)

    return render(
        request,
        "dashboard/officers/officer_list.html",
        {
            "officers": officers,
            "organization_type_choices": Officer.ORGANIZATION_TYPE_CHOICES,
            "selected_organization_type": organization_type,
            "selected_duty_status": duty_status,
            "query": query,
            "on_duty_count": Officer.objects.filter(is_active=True, is_on_duty=True).count(),
            "off_duty_count": Officer.objects.filter(is_active=True, is_on_duty=False).count(),
        },
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def officer_create(request):
    if request.method == "POST":
        Officer.objects.create(
            full_name=request.POST.get("full_name", "").strip(),
            badge_number=request.POST.get("badge_number", "").strip(),
            phone_number=request.POST.get("phone_number", "").strip(),
            email=request.POST.get("email", "").strip(),
            organization_type=request.POST.get("organization_type", "police"),
            organization_name=request.POST.get("organization_name", "").strip(),
            registered_by=request.user,
        )
        messages.success(request, "Officer registered.")
        return redirect("dashboard:officer_list")

    return render(
        request,
        "dashboard/officers/officer_create.html",
        {"organization_type_choices": Officer.ORGANIZATION_TYPE_CHOICES},
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def officer_detail(request, pk):
    officer = get_object_or_404(Officer, pk=pk)
    return render(
        request,
        "dashboard/officers/officer_detail.html",
        {"officer": officer, "duty_logs": officer.duty_logs.select_related("changed_by")[:20]},
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def officer_toggle_duty(request, pk):
    officer = get_object_or_404(Officer, pk=pk)
    if request.method == "POST":
        officer.is_on_duty = not officer.is_on_duty
        officer.save()
        OfficerDutyLog.objects.create(officer=officer, is_on_duty=officer.is_on_duty, changed_by=request.user)
        messages.success(request, f"{officer.full_name} marked {'On Duty' if officer.is_on_duty else 'Off Duty'}.")
    return redirect(request.POST.get("next") or "dashboard:officer_list")


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def officer_remove(request, pk):
    officer = get_object_or_404(Officer, pk=pk)
    if request.method == "POST":
        officer.is_active = False
        officer.is_on_duty = False
        officer.save()
        messages.success(request, f"{officer.full_name} removed from the roster.")
    return redirect("dashboard:officer_list")