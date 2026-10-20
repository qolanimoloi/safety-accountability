from django.urls import path
from . import api_views, live_views

urlpatterns = [
    path("live/me/", live_views.live_me, name="api_live_me"),
    path("live/update/", live_views.live_update, name="api_live_update"),
    path("live/contacts/", live_views.live_contacts, name="api_live_contacts"),
    path("trigger/", api_views.trigger_emergency, name="api_trigger_emergency"),
    path("contacts/", api_views.contact_list_create, name="api_contact_list_create"),
    path("contacts/add-user/", api_views.contact_add_user, name="api_contact_add_user"),
    path("contacts/requests/", api_views.contact_requests, name="api_contact_requests"),
    path("contacts/<int:pk>/respond/", api_views.contact_respond, name="api_contact_respond"),
    path("contacts/<int:pk>/", api_views.contact_delete, name="api_contact_delete"),
    path("alerts-for-me/", api_views.alerts_for_me, name="api_alerts_for_me"),
    path("<str:reference>/status/", api_views.emergency_status, name="api_emergency_status"),
    path("<str:reference>/resolve/", api_views.mark_resolved, name="api_resolve_emergency"),
]