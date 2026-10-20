from django.contrib import admin

from .models import AnonymousReport, ReportEvidence


class ReportEvidenceInline(admin.TabularInline):
    model = ReportEvidence
    extra = 0
    readonly_fields = ("original_filename", "content_type", "size_bytes", "uploaded_at")


@admin.register(AnonymousReport)
class AnonymousReportAdmin(admin.ModelAdmin):
    list_display = ("tracking_code", "category", "urgency", "status", "created_at")
    list_filter = ("category", "urgency", "status", "involves_minors", "requires_immediate_action")
    search_fields = ("tracking_code", "description", "location")
    readonly_fields = ("tracking_code", "created_at", "updated_at")
    inlines = [ReportEvidenceInline]