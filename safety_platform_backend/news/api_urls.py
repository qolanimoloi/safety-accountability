from django.urls import path
from . import api_views

urlpatterns = [
    path("", api_views.news_list, name="news_list"),
    path("stats/", api_views.news_stats, name="news_stats"),
]