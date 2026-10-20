from django.contrib.auth import views as auth_views
from django.urls import path

from activity_log import dashboard_views as activity_views
from community import dashboard_views as community_views
from ehailing import dashboard_views as ehailing_views
from emergencies import dashboard_views as emergency_views
from news import dashboard_views as news_views
from officers import dashboard_views as officer_views
from reports import dashboard_views as report_views
from . import live_views, views

app_name = "dashboard"

urlpatterns = [
    path("login/", views.DashboardLoginView.as_view(), name="login"),
    path("logout/", auth_views.LogoutView.as_view(), name="logout"),
    path("", views.home, name="home"),
    path("live/pending/", live_views.pending, name="live_pending"),
    path("accounts/", views.account_list, name="account_list"),
    path("accounts/<int:pk>/", views.account_detail, name="account_detail"),
    path("officers/", officer_views.officer_list, name="officer_list"),
    path("officers/new/", officer_views.officer_create, name="officer_create"),
    path("officers/<int:pk>/", officer_views.officer_detail, name="officer_detail"),
    path("officers/<int:pk>/toggle-duty/", officer_views.officer_toggle_duty, name="officer_toggle_duty"),
    path("officers/<int:pk>/remove/", officer_views.officer_remove, name="officer_remove"),
    path("reports/", report_views.report_list, name="report_list"),
    path("reports/<int:pk>/", report_views.report_detail, name="report_detail"),
    path("emergencies/", emergency_views.emergency_list, name="emergency_list"),
    path("emergencies/<int:pk>/", emergency_views.emergency_detail, name="emergency_detail"),
    path("activity-log/", activity_views.activity_list, name="activity_list"),
    path("activity-log/<int:pk>/", activity_views.activity_detail, name="activity_detail"),
    path("community/", community_views.post_list, name="post_list"),
    path("community/new/", community_views.create_official_post, name="create_official_post"),
    path("community/<int:pk>/", community_views.post_detail, name="post_detail"),
    path("news/", news_views.news_list, name="news_list"),
    path("news/new/", news_views.news_create, name="news_create"),
    path("news/<int:pk>/delete/", news_views.news_delete, name="news_delete"),
    path("ehailing/panic/", ehailing_views.panic_list, name="ehailing_panic_list"),
    path("ehailing/panic/<int:pk>/", ehailing_views.panic_detail, name="ehailing_panic_detail"),
    path("ehailing/trips/", ehailing_views.trip_list, name="ehailing_trip_list"),
    path("ehailing/passenger-logs/", ehailing_views.passenger_log_list, name="ehailing_passenger_log_list"),
    path("ehailing/communities/", ehailing_views.community_list, name="ehailing_community_list"),
    path("ehailing/communities/<int:pk>/", ehailing_views.community_detail, name="ehailing_community_detail"),
]