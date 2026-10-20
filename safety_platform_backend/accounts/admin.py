from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import User


@admin.register(User)
class AppUserAdmin(UserAdmin):
    """
    Registers our custom User with Django's own /admin/ too, as a backup
    view into accounts while the web dashboard (the real admin UI,
    dashboard app) is being built out.
    """

    model = User
    list_display = ("email", "full_name", "phone_number", "is_active_account", "is_dashboard_admin", "date_joined_app")
    list_filter = ("is_active_account", "is_dashboard_admin", "is_staff")
    search_fields = ("email", "full_name", "phone_number")
    ordering = ("-date_joined_app",)
    fieldsets = (
        (None, {"fields": ("email", "username", "password")}),
        ("Profile", {"fields": ("full_name", "phone_number")}),
        ("Status", {"fields": ("is_active_account", "is_dashboard_admin", "is_active", "is_staff", "is_superuser")}),
        ("Permissions", {"fields": ("groups", "user_permissions")}),
        ("Important dates", {"fields": ("last_login", "date_joined_app")}),
    )
    readonly_fields = ("date_joined_app",)
