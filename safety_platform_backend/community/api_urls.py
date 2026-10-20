from django.urls import path

from . import api_views

urlpatterns = [
    path("posts/", api_views.post_list_create, name="api_post_list_create"),
    path("posts/<int:pk>/like/", api_views.toggle_like, name="api_toggle_like"),
    path("posts/<int:pk>/comments/", api_views.comment_list_create, name="api_comment_list_create"),
    path("posts/<int:pk>/share/", api_views.share_post, name="api_share_post"),
    path("posts/<int:pk>/report/", api_views.report_post, name="api_report_post"),
    path("quick-alert/", api_views.quick_alert, name="api_quick_alert"),
]