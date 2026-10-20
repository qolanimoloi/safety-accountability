from django.urls import path
from . import api_views

urlpatterns = [
    path("conversations/", api_views.conversation_list_create, name="conversation_list_create"),
    path("conversations/<int:pk>/messages/", api_views.message_list_create, name="message_list_create"),
    path("conversations/<int:pk>/read/", api_views.mark_read, name="mark_read"),
    path("users/search/", api_views.search_users, name="chat_search_users"),
]