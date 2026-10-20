from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.shortcuts import get_object_or_404, redirect, render
from .models import NewsPost
from .stats import compute_stats


def _is_dashboard_admin(user):
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def news_list(request):
    posts = NewsPost.objects.select_related("posted_by")
    category = request.GET.get("category", "")
    if category:
        posts = posts.filter(category=category)
    return render(
        request,
        "dashboard/news/news_list.html",
        {
            "posts": posts,
            "category_choices": NewsPost.CATEGORY_CHOICES,
            "selected_category": category,
            "week_stats": compute_stats(7),
            "month_stats": compute_stats(30),
        },
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def news_create(request):
    if request.method == "POST":
        NewsPost.objects.create(
            title=request.POST.get("title", "").strip(),
            body=request.POST.get("body", "").strip(),
            category=request.POST.get("category", "tip"),
            posted_by=request.user,
        )
        messages.success(request, "Published to all users.")
        return redirect("dashboard:news_list")
    return render(request, "dashboard/news/news_create.html", {"category_choices": NewsPost.CATEGORY_CHOICES})


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def news_delete(request, pk):
    post = get_object_or_404(NewsPost, pk=pk)
    if request.method == "POST":
        post.delete()
        messages.success(request, "Post removed.")
    return redirect("dashboard:news_list")