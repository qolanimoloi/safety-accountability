from django.urls import path
from . import api_views

urlpatterns = [
    path("", api_views.activity_list_create, name="activity_list_create"),
    path("shared-with-me/", api_views.shared_with_me, name="activity_shared_with_me"),
    path("<int:pk>/", api_views.activity_detail, name="activity_detail"),
    path("<int:pk>/mark-safe/", api_views.activity_mark_safe, name="activity_mark_safe"),
    path("<int:pk>/escalate/", api_views.activity_escalate, name="activity_escalate"),
]