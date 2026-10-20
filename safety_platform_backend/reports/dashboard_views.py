from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.shortcuts import get_object_or_404, redirect, render

from .models import AnonymousReport


def _is_dashboard_admin(user):
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def report_list(request):
    reports = AnonymousReport.objects.all().prefetch_related("evidence")

    status = request.GET.get("status", "")
    category = request.GET.get("category", "")
    urgency = request.GET.get("urgency", "")
    query = request.GET.get("q", "").strip()

    if status:
        reports = reports.filter(status=status)
    if category:
        reports = reports.filter(category=category)
    if urgency:
        reports = reports.filter(urgency=urgency)
    if query:
        reports = reports.filter(tracking_code__icontains=query)

    return render(
        request,
        "dashboard/reports/report_list.html",
        {
            "reports": reports,
            "status_choices": AnonymousReport.STATUS_CHOICES,
            "category_choices": AnonymousReport.CATEGORY_CHOICES,
            "urgency_choices": AnonymousReport.URGENCY_CHOICES,
            "selected_status": status,
            "selected_category": category,
            "selected_urgency": urgency,
            "query": query,
        },
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def report_detail(request, pk):
    report = get_object_or_404(AnonymousReport, pk=pk)

    if request.method == "POST":
        report.status = request.POST.get("status", report.status)
        report.admin_notes = request.POST.get("admin_notes", report.admin_notes)
        report.save()
        messages.success(request, f"Updated {report.tracking_code}.")
        return redirect("dashboard:report_detail", pk=report.pk)

    return render(request, "dashboard/reports/report_detail.html", {"report": report})