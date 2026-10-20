from django.contrib import admin

from .models import CommunityPost, PostComment, PostReaction, PostReport, PostShare


class PostReportInline(admin.TabularInline):
    model = PostReport
    extra = 0
    readonly_fields = ("reporter", "reason", "details", "created_at")


class PostCommentInline(admin.TabularInline):
    model = PostComment
    extra = 0
    readonly_fields = ("author", "content", "created_at")


@admin.register(CommunityPost)
class CommunityPostAdmin(admin.ModelAdmin):
    list_display = ("id", "author", "post_type", "category", "status", "is_official", "reports_count_display", "created_at")
    list_filter = ("post_type", "category", "status", "is_official", "is_quick_alert")
    search_fields = ("content", "author__email", "author__full_name")
    readonly_fields = ("created_at", "updated_at")
    inlines = [PostReportInline, PostCommentInline]

    @admin.display(description="Reports")
    def reports_count_display(self, obj):
        return obj.reports_count


@admin.register(PostReport)
class PostReportAdmin(admin.ModelAdmin):
    list_display = ("post", "reporter", "reason", "resolved", "created_at")
    list_filter = ("reason", "resolved")


admin.site.register(PostReaction)
admin.site.register(PostComment)
admin.site.register(PostShare)