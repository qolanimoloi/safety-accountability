from django.urls import path
from . import api_views

urlpatterns = [
    path("trips/", api_views.trip_create, name="trip_create"),
    path("trips/<int:pk>/end/", api_views.trip_end, name="trip_end"),

    path("communities/", api_views.community_list_create, name="community_list_create"),
    path("communities/<int:pk>/join/", api_views.community_join, name="community_join"),
    path("communities/<int:pk>/leave/", api_views.community_leave, name="community_leave"),
    path("communities/<int:pk>/posts/", api_views.community_post_list_create, name="community_post_list_create"),

    path("passenger-logs/", api_views.passenger_log_create, name="passenger_log_create"),
    path("passenger-logs/<int:pk>/drop-off/", api_views.passenger_log_drop_off, name="passenger_log_drop_off"),

    path("panic/", api_views.panic_trigger, name="panic_trigger"),
    path("panic/<int:pk>/status/", api_views.panic_status, name="panic_status"),
    path("panic/<int:pk>/resolve/", api_views.panic_resolve, name="panic_resolve"),
]