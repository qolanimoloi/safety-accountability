from django.urls import path
from . import api_views, profile_views

urlpatterns = [
    path("signup/", api_views.signup, name="signup"),
    path("login/", api_views.login, name="login"),
    path("me/", api_views.me, name="me"),
    path("profile-photo/", api_views.profile_photo, name="profile_photo"),
    path("change-password/", api_views.change_password, name="change_password"),
    path("google/", api_views.google_login, name="google_login"),
    path("phone/", api_views.set_phone, name="set_phone"),
    path("privacy/", profile_views.privacy_settings, name="privacy_settings"),
    path("users/<int:pk>/", profile_views.public_profile, name="public_profile"),
]