from django.conf import settings
from django.contrib.auth import authenticate
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from rest_framework import permissions, status
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.response import Response

from .models import User
from .photo_hash import dhash_hex, is_same_picture
from .serializers import (
    ChangePasswordSerializer,
    LoginSerializer,
    ProfilePhotoSerializer,
    SignupSerializer,
    UserSerializer,
)
from .validators import SA_MOBILE_MESSAGE, normalize_sa_mobile


def _user_data(user, request):
    # Always pass the request so the picture address is a full https:// address
    # the app can load, not a bare /media/... path.
    return UserSerializer(user, context={"request": request}).data


# --------------------------------------------------
# SIGNUP
# --------------------------------------------------

@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def signup(request):
    serializer = SignupSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    user = serializer.save()
    token, _ = Token.objects.get_or_create(user=user)

    return Response(
        {"token": token.key, "user": _user_data(user, request)},
        status=status.HTTP_201_CREATED,
    )


# --------------------------------------------------
# LOGIN
# --------------------------------------------------

@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def login(request):
    serializer = LoginSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    email = serializer.validated_data["email"].strip().lower()
    password = serializer.validated_data["password"]

    user = authenticate(request, username=email, password=password)

    if user is None:
        return Response(
            {"detail": "Incorrect email or password."},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    if not user.is_active_account:
        return Response(
            {"detail": "This account has been deactivated. Contact support."},
            status=status.HTTP_403_FORBIDDEN,
        )

    token, _ = Token.objects.get_or_create(user=user)

    return Response(
        {"token": token.key, "user": _user_data(user, request)},
        status=status.HTTP_200_OK,
    )


# --------------------------------------------------
# GOOGLE LOGIN
# --------------------------------------------------

@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def google_login(request):
    """
    Sign up / log in with Google. The app sends the ID token it got from
    Google; we verify it with Google's public keys, then find or create the
    matching user (matched on the verified email) and return our own token,
    exactly like the normal login.
    """
    raw_token = (request.data.get("id_token") or "").strip()
    if not raw_token:
        return Response({"detail": "Missing Google token."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        info = google_id_token.verify_oauth2_token(raw_token, google_requests.Request())
    except ValueError:
        return Response(
            {"detail": "Google sign-in could not be verified. Please try again."},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    # The token must have been issued for OUR app, not some other app's client id.
    if info.get("aud") not in getattr(settings, "GOOGLE_CLIENT_IDS", []):
        return Response(
            {"detail": "Google sign-in is not set up for this app."},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    email = (info.get("email") or "").strip().lower()
    if not email or not info.get("email_verified"):
        return Response({"detail": "Your Google email is not verified."}, status=status.HTTP_400_BAD_REQUEST)

    user = User.objects.filter(email__iexact=email).first()
    created = False
    if user is None:
        user = User(email=email, full_name=(info.get("name") or "").strip()[:150])
        user.set_unusable_password()  # they sign in with Google, there is no password
        user.save()
        created = True

    if not user.is_active_account:
        return Response(
            {"detail": "This account has been deactivated. Contact support."},
            status=status.HTTP_403_FORBIDDEN,
        )

    token, _ = Token.objects.get_or_create(user=user)
    return Response(
        {
            "token": token.key,
            "user": _user_data(user, request),
            "is_new": created,
            "needs_phone": not user.phone_number,
        },
        status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
    )


# --------------------------------------------------
# SET PHONE NUMBER (for accounts created with Google)
# --------------------------------------------------

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def set_phone(request):
    """Lets a Google-created account add the phone number the signup form would have collected."""
    phone = normalize_sa_mobile(str(request.data.get("phone_number") or "").strip())
    if phone is None:
        return Response({"phone_number": [SA_MOBILE_MESSAGE]}, status=status.HTTP_400_BAD_REQUEST)

    request.user.phone_number = phone
    request.user.save(update_fields=["phone_number"])
    return Response(_user_data(request.user, request))


# --------------------------------------------------
# CURRENT USER PROFILE
# --------------------------------------------------

@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def me(request):
    return Response(_user_data(request.user, request), status=status.HTTP_200_OK)


# --------------------------------------------------
# PROFILE PHOTO (upload = POST, remove = DELETE)
# --------------------------------------------------

@api_view(["POST", "DELETE"])
@permission_classes([permissions.IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def profile_photo(request):
    """
    POST   multipart with a file field named 'photo' -> saves it as the profile picture.
    DELETE -> removes the profile picture.
    Both return the updated user, which is what the app stores.

    A picture that is already the profile picture of ANOTHER account is
    refused, to make fake accounts built on someone else's photo harder.
    """
    user = request.user

    if request.method == "DELETE":
        if user.profile_photo:
            user.profile_photo.delete(save=False)
        user.photo_hash = ""
        user.save(update_fields=["profile_photo", "photo_hash"])
        return Response(_user_data(user, request))

    upload = request.FILES.get("photo") or request.FILES.get("profile_photo")
    if upload is None:
        return Response(
            {"detail": "No picture was sent. Please choose a picture and try again."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    serializer = ProfilePhotoSerializer(data={"photo": upload})
    serializer.is_valid(raise_exception=True)  # real image, under 5MB
    upload = serializer.validated_data["photo"]

    try:
        new_hash = dhash_hex(upload)
    except Exception:
        return Response(
            {"detail": "That file could not be read as a picture. Please choose another one."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    other_hashes = User.objects.exclude(pk=user.pk).exclude(photo_hash="").values_list("photo_hash", flat=True)
    if any(is_same_picture(new_hash, other) for other in other_hashes):
        return Response(
            {"detail": "This picture is already used on another account. Please use your own photo."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if user.profile_photo:
        user.profile_photo.delete(save=False)
    user.profile_photo = upload
    user.photo_hash = new_hash
    user.save(update_fields=["profile_photo", "photo_hash"])

    return Response(_user_data(user, request), status=status.HTTP_200_OK)


# --------------------------------------------------
# CHANGE PASSWORD
# --------------------------------------------------

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def change_password(request):
    """
    Change the authenticated user's password and invalidate
    their existing DRF authentication token.
    """
    serializer = ChangePasswordSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    if not request.user.check_password(serializer.validated_data["current_password"]):
        return Response(
            {"current_password": ["Current password is incorrect."]},
            status=status.HTTP_400_BAD_REQUEST,
        )

    request.user.set_password(serializer.validated_data["new_password"])
    request.user.save()

    # Invalidate the existing authentication token.
    Token.objects.filter(user=request.user).delete()

    return Response(
        {"detail": "Password changed successfully. Please log in again."},
        status=status.HTTP_200_OK,
    )