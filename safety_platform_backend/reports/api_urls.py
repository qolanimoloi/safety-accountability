from django.urls import path

from . import api_views

urlpatterns = [
    path("submit/", api_views.submit_report, name="api_submit_report"),
    path("track/<str:tracking_code>/", api_views.track_report, name="api_track_report"),
]