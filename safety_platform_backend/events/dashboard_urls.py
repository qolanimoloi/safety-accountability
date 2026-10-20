from django.urls import path

from . import dashboard_views as views

app_name = "events_admin"

urlpatterns = [
    path("", views.event_list, name="list"),
    path("incidents/", views.incident_list, name="incident_list"),
    path("incidents/<int:pk>/", views.incident_detail, name="incident_detail"),
    path("api/pending/", views.pending_json, name="pending"),
    path("<int:pk>/", views.event_detail, name="detail"),
    path("<int:pk>/visibility/", views.event_visibility, name="visibility"),
]