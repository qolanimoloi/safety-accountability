from django.contrib.auth import views as auth_views
from django.contrib.auth.decorators import login_required, user_passes_test
from django.contrib.auth import get_user_model
from django.shortcuts import render, get_object_or_404, redirect
from django.contrib import messages

User = get_user_model()


def _is_dashboard_admin(user):
    # Gate every dashboard page behind this, not just is_staff: this is
    # the "who can see the dashboard" flag from the User model, kept
    # separate from Django's own /admin/ permissions.
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


class DashboardLoginView(auth_views.LoginView):
    template_name = "registration/login.html"
    redirect_authenticated_user = True


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def home(request):
    from community.models import CommunityPost, PostReport
    from emergencies.models import EmergencyReport
    from reports.models import AnonymousReport

    open_emergencies = EmergencyReport.objects.exclude(status__in=["resolved", "unresponded"])

    context = {
        "total_accounts": User.objects.count(),
        "active_accounts": User.objects.filter(is_active_account=True).count(),
        "total_reports": AnonymousReport.objects.count(),
        "open_reports": AnonymousReport.objects.exclude(status="resolved").count(),
        "critical_reports": AnonymousReport.objects.filter(urgency="critical").exclude(status="resolved").count(),
        "open_emergencies": open_emergencies.count(),
        "overdue_emergencies": sum(1 for e in open_emergencies if e.is_overdue),
        "total_posts": CommunityPost.objects.filter(status="published").count(),
        "unresolved_post_reports": PostReport.objects.filter(resolved=False).count(),
        # E-hailing will add its own counts here once it's built.
    }
    return render(request, "dashboard/home.html", context)


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def account_list(request):
    query = request.GET.get("q", "").strip()
    accounts = User.objects.all().order_by("-date_joined_app")
    if query:
        accounts = accounts.filter(email__icontains=query) | accounts.filter(full_name__icontains=query)
    return render(request, "dashboard/account_list.html", {"accounts": accounts, "query": query})


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def account_detail(request, pk):
    account = get_object_or_404(User, pk=pk)

    if request.method == "POST":
        account.full_name = request.POST.get("full_name", account.full_name)
        account.phone_number = request.POST.get("phone_number", account.phone_number)
        account.is_active_account = request.POST.get("is_active_account") == "on"
        account.is_dashboard_admin = request.POST.get("is_dashboard_admin") == "on"
        account.save()
        messages.success(request, f"Updated {account.email}.")
        return redirect("dashboard:account_detail", pk=account.pk)

    return render(request, "dashboard/account_detail.html", {"account": account})
