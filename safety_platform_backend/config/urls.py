from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("dashboard/events/", include("events.dashboard_urls")),
    path("", include("dashboard.urls")),
    path("api/accounts/", include("accounts.api_urls")),
    path("api/reports/", include("reports.api_urls")),
    path("api/emergencies/", include("emergencies.api_urls")),
    path("api/community/", include("community.api_urls")),
    path("api/ehailing/", include("ehailing.api_urls")),
    path("api/activity-log/", include("activity_log.api_urls")),
    path("api/news/", include("news.api_urls")),
    path("api/chat/", include("chat.api_urls")),
    path("api/events/", include("events.api_urls")),
    path("api/notifications/", include("notifications.api_urls")),
    path("api/circles/", include("circles.api_urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)