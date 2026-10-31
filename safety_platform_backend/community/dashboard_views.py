from django.contrib import messages
from django.contrib.auth.decorators import login_required, user_passes_test
from django.shortcuts import get_object_or_404, redirect, render
from .models import (
    CommunityPost,
    PostMedia,
    ALLOWED_IMAGE_EXTENSIONS,
    ALLOWED_VIDEO_EXTENSIONS,
    MAX_POST_MEDIA_SIZE_BYTES,
)


def _is_dashboard_admin(user):
    return user.is_authenticated and (user.is_dashboard_admin or user.is_superuser)


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def post_list(request):
    posts = CommunityPost.objects.select_related("author").prefetch_related("reports", "media")

    status = request.GET.get("status", "")
    post_type = request.GET.get("post_type", "")
    reported_only = request.GET.get("reported_only") == "1"

    if status:
        posts = posts.filter(status=status)
    if post_type:
        posts = posts.filter(post_type=post_type)
    if reported_only:
        posts = posts.filter(reports__resolved=False).distinct()

    return render(
        request,
        "dashboard/community/post_list.html",
        {
            "posts": posts,
            "status_choices": CommunityPost.STATUS_CHOICES,
            "post_type_choices": CommunityPost.POST_TYPE_CHOICES,
            "selected_status": status,
            "selected_post_type": post_type,
            "reported_only": reported_only,
        },
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def post_detail(request, pk):
    post = get_object_or_404(CommunityPost, pk=pk)

    if request.method == "POST":
        action = request.POST.get("action")
        if action == "set_status":
            post.status = request.POST.get("status", post.status)
            post.save()
            messages.success(request, f"Post status set to {post.get_status_display()}.")
        elif action == "resolve_report":
            report_id = request.POST.get("report_id")
            report = get_object_or_404(post.reports, pk=report_id)
            report.mark_resolved(notes=request.POST.get("admin_notes", ""))
            messages.success(request, "Report marked resolved.")
        return redirect("dashboard:post_detail", pk=post.pk)

    return render(
        request,
        "dashboard/community/post_detail.html",
        {"post": post, "comments": post.comments.select_related("author"), "reports": post.reports.select_related("reporter")},
    )


@login_required(login_url="dashboard:login")
@user_passes_test(_is_dashboard_admin, login_url="dashboard:login")
def create_official_post(request):
    """
    Lets an admin post directly from the dashboard, not just through the
    app — e.g. a desk officer issuing a verified community alert without
    needing the Flutter app open. is_official is always True here since
    only a dashboard admin can reach this view at all.
    """
    if request.method == "POST":
        post = CommunityPost.objects.create(
            author=request.user,
            post_type=request.POST.get("post_type", "alert"),
            category=request.POST.get("category", "general_alert"),
            content=request.POST.get("content", "").strip(),
            location_description=request.POST.get("location_description", ""),
            is_official=True,
        )
        for index, f in enumerate(request.FILES.getlist("media")):
            ext = f.name.rsplit(".", 1)[-1].lower() if "." in f.name else ""
            if ext not in ALLOWED_IMAGE_EXTENSIONS | ALLOWED_VIDEO_EXTENSIONS:
                messages.warning(request, f"{f.name} was skipped: only JPG, PNG, MP4 and MOV files are allowed.")
                continue
            if f.size > MAX_POST_MEDIA_SIZE_BYTES:
                messages.warning(request, f"{f.name} was skipped: it is larger than 60MB.")
                continue
            media_type = "video" if ext in ALLOWED_VIDEO_EXTENSIONS else "image"
            PostMedia.objects.create(
                post=post,
                file=f,
                media_type=media_type,
                original_filename=f.name,
                content_type=getattr(f, "content_type", "") or "",
                size_bytes=f.size,
                order=index,
            )
        messages.success(request, "Official post published.")
        return redirect("dashboard:post_detail", pk=post.pk)

    return render(
        request,
        "dashboard/community/create_post.html",
        {"post_type_choices": CommunityPost.POST_TYPE_CHOICES, "category_choices": CommunityPost.CATEGORY_CHOICES},
    )