from django.urls import path
from . import api_views

urlpatterns = [
    path("", api_views.notification_list, name="notification_list"),
    path("mark-all-read/", api_views.mark_all_read, name="notification_mark_all_read"),
    path("<int:pk>/read/", api_views.mark_one_read, name="notification_mark_one_read"),
]