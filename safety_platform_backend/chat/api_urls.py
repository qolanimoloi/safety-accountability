from django.urls import path
from . import api_views

urlpatterns = [
    path("conversations/", api_views.conversation_list_create, name="conversation_list_create"),
    path("conversations/<int:pk>/messages/", api_views.message_list_create, name="message_list_create"),
    path("conversations/<int:pk>/read/", api_views.mark_read, name="mark_read"),
    path("conversations/<int:pk>/icon/", api_views.conversation_icon, name="conversation_icon"),
    path("conversations/<int:pk>/reactions/", api_views.conversation_reactions, name="conversation_reactions"),
    path("messages/<int:pk>/react/", api_views.message_react, name="message_react"),
    path("users/search/", api_views.search_users, name="chat_search_users"),
]