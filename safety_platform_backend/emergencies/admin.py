from django.contrib import admin

from .models import EmergencyReport


@admin.register(EmergencyReport)
class EmergencyReportAdmin(admin.ModelAdmin):
    list_display = ("reference", "incident_type", "status", "user", "created_at", "is_overdue")
    list_filter = ("incident_type", "status")
    search_fields = ("reference", "user__email", "user__full_name", "location_description")
    readonly_fields = ("reference", "created_at", "updated_at")

    @admin.display(boolean=True, description="Overdue")
    def is_overdue(self, obj):
        return obj.is_overdue