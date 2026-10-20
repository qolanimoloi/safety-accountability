from django.urls import path

from . import api_views

urlpatterns = [
    path("", api_views.event_list_create, name="api_event_list_create"),
    path("hosting/", api_views.hosting_list, name="api_event_hosting"),
    path("incidents/<int:pk>/status/", api_views.incident_set_status, name="api_incident_set_status"),
    path("incidents/track/<str:reference>/", api_views.incident_track, name="api_incident_track"),
    path("<int:pk>/", api_views.event_detail, name="api_event_detail"),
    path("<int:pk>/cancel/", api_views.event_cancel, name="api_event_cancel"),
    path("<int:pk>/attend/", api_views.event_attend, name="api_event_attend"),
    path("<int:pk>/leave/", api_views.event_leave, name="api_event_leave"),
    path("<int:pk>/incidents/", api_views.incident_list_create, name="api_incident_list_create"),
]