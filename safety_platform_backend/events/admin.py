from django.contrib import admin

from .models import Event, EventAttendance, EventIncident, IncidentEvidence


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ("title", "host", "start_at", "end_at", "status")
    list_filter = ("status", "category")
    search_fields = ("title", "venue_name")


@admin.register(EventAttendance)
class EventAttendanceAdmin(admin.ModelAdmin):
    list_display = ("event", "user", "joined_at")


class IncidentEvidenceInline(admin.TabularInline):
    model = IncidentEvidence
    extra = 0
    readonly_fields = ("file", "original_filename", "content_type", "size_bytes", "uploaded_at")


@admin.register(EventIncident)
class EventIncidentAdmin(admin.ModelAdmin):
    list_display = ("reference", "event", "kind", "severity", "status", "is_anonymous", "created_at")
    list_filter = ("status", "severity", "kind")
    inlines = [IncidentEvidenceInline]