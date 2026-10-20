
from django.conf import settings
from django.contrib.auth import authenticate
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from rest_framework import permissions, status
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, permission_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response

from .models import User
from .serializers import (
    ChangePasswordSerializer,
    LoginSerializer,
    SignupSerializer,
    UserSerializer,
)

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
        {
            "token": token.key,
            "user": UserSerializer(user).data,
        },
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

    user = authenticate(
        request,
        username=email,
        password=password,
    )

    if user is None:
        return Response(
            {"detail": "Incorrect email or password."},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    if not user.is_active_account:
        return Response(
            {
                "detail": (
                    "This account has been deactivated. "
                    "Contact support."
                )
            },
            status=status.HTTP_403_FORBIDDEN,
        )

    token, _ = Token.objects.get_or_create(user=user)

    return Response(
        {
            "token": token.key,
            "user": UserSerializer(user).data,
        },
        status=status.HTTP_200_OK,
    )


# --------------------------------------------------
# GOOGLE LOGIN
# --------------------------------------------------

@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def google_login(request):
    """
    Verify a Google ID token, find or create the user,
    and return a Django REST Framework authentication token.
    """

    raw_token = (request.data.get("id_token") or "").strip()

    if not raw_token:
        return Response(
            {"detail": "Missing Google token."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        info = google_id_token.verify_oauth2_token(
            raw_token,
            google_requests.Request(),
        )
    except ValueError:
        return Response(
            {
                "detail": (
                    "Google sign-in could not be verified. "
                    "Please try again."
                )
            },
            status=status.HTTP_401_UNAUTHORIZED,
        )

    allowed_client_ids = getattr(
        settings,
        "GOOGLE_CLIENT_IDS",
        [],
    )

    if info.get("aud") not in allowed_client_ids:
        return Response(
            {
                "detail": (
                    "Google sign-in is not set up for this app."
                )
            },
            status=status.HTTP_401_UNAUTHORIZED,
        )

    email = (info.get("email") or "").strip().lower()

    if not email or not info.get("email_verified"):
        return Response(
            {"detail": "Your Google email is not verified."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = User.objects.filter(email__iexact=email).first()
    created = False

    if user is None:
        user = User(
            email=email,
            full_name=(info.get("name") or "").strip()[:150],
        )
        user.set_unusable_password()
        user.save()
        created = True

    if not user.is_active_account:
        return Response(
            {
                "detail": (
                    "This account has been deactivated. "
                    "Contact support."
                )
            },
            status=status.HTTP_403_FORBIDDEN,
        )

    token, _ = Token.objects.get_or_create(user=user)

    return Response(
        {
            "token": token.key,
            "user": UserSerializer(user).data,
            "is_new": created,
            "needs_phone": not user.phone_number,
        },
        status=(
            status.HTTP_201_CREATED
            if created
            else status.HTTP_200_OK
        ),
    )


# --------------------------------------------------
# SET PHONE NUMBER
# --------------------------------------------------

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def set_phone(request):
    """
    Allow an authenticated user to add or update their phone number.
    """

    phone = str(
        request.data.get("phone_number") or ""
    ).strip()

    digits = "".join(
        ch for ch in phone
        if ch.isdigit()
    )

    if len(digits) < 10:
        return Response(
            {
                "phone_number": [
                    "Enter a valid phone number."
                ]
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    request.user.phone_number = phone[:20]
    request.user.save(
        update_fields=["phone_number"]
    )

    return Response(
        UserSerializer(request.user).data,
        status=status.HTTP_200_OK,
    )


# --------------------------------------------------
# CURRENT USER PROFILE
# --------------------------------------------------

@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def me(request):
    """
    Return the currently authenticated user's profile.
    """

    return Response(
        UserSerializer(request.user).data,
        status=status.HTTP_200_OK,
    )


# --------------------------------------------------
# UPLOAD PROFILE PHOTO
# --------------------------------------------------

@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def profile_photo(request):
    """
    Upload a profile photo for the currently authenticated user.

    Expects multipart/form-data with a file field named
    'profile_photo'.

    IMPORTANT:
    This implementation assumes your User model has an
    ImageField named 'profile_photo'.
    """

    photo = request.FILES.get("profile_photo")

    if photo is None:
        return Response(
            {
                "detail": (
                    "No profile photo was uploaded. "
                    "Use the 'profile_photo' file field."
                )
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Basic file type and size validation.
    allowed_types = {
        "image/jpeg",
        "image/png",
        "image/webp",
    }

    if getattr(photo, "content_type", None) not in allowed_types:
        return Response(
            {
                "profile_photo": [
                    "Upload a JPEG, PNG, or WebP image."
                ]
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    max_size = 5 * 1024 * 1024  # 5 MB

    if photo.size > max_size:
        return Response(
            {
                "profile_photo": [
                    "The image must be 5 MB or smaller."
                ]
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = request.user

    # This field must exist on your custom User model.
    user.profile_photo = photo
    user.save(update_fields=["profile_photo"])

    photo_url = (
        request.build_absolute_uri(user.profile_photo.url)
        if user.profile_photo
        else None
    )

    return Response(
        {
            "message": "Profile photo updated successfully.",
            "profile_photo": photo_url,
            "user": UserSerializer(user).data,
        },
        status=status.HTTP_200_OK,
    )


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

    serializer = ChangePasswordSerializer(
        data=request.data
    )
    serializer.is_valid(raise_exception=True)

    if not request.user.check_password(
        serializer.validated_data["current_password"]
    ):
        return Response(
            {
                "current_password": [
                    "Current password is incorrect."
                ]
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    request.user.set_password(
        serializer.validated_data["new_password"]
    )
    request.user.save()

    # Invalidate the existing authentication token.
    Token.objects.filter(
        user=request.user
    ).delete()

    return Response(
        {
            "detail": (
                "Password changed successfully. "
                "Please log in again."
            )
        },
        status=status.HTTP_200_OK,
    )


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
        return Response({"detail": "Google sign-in could not be verified. Please try again."}, status=status.HTTP_401_UNAUTHORIZED)

    # The token must have been issued for OUR app, not some other app's client id.
    if info.get("aud") not in getattr(settings, "GOOGLE_CLIENT_IDS", []):
        return Response({"detail": "Google sign-in is not set up for this app."}, status=status.HTTP_401_UNAUTHORIZED)

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
        return Response({"detail": "This account has been deactivated. Contact support."}, status=status.HTTP_403_FORBIDDEN)

    token, _ = Token.objects.get_or_create(user=user)
    return Response(
        {
            "token": token.key,
            "user": UserSerializer(user, context={"request": request}).data,
            "is_new": created,
            "needs_phone": not user.phone_number,
        },
        status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
    )


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def set_phone(request):
    """Lets a Google-created account add the phone number the signup form would have collected."""
    phone = str(request.data.get("phone_number") or "").strip()
    digits = "".join(ch for ch in phone if ch.isdigit() or ch == "+")
    if len(digits) < 10:
        return Response({"phone_number": ["Enter a valid phone number."]}, status=status.HTTP_400_BAD_REQUEST)
    request.user.phone_number = phone[:20]
    request.user.save(update_fields=["phone_number"])
    return Response(UserSerializer(request.user, context={"request": request}).data)