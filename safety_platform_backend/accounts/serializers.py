from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from .models import User
from .validators import SA_MOBILE_MESSAGE, normalize_sa_mobile

MAX_PROFILE_PHOTO_BYTES = 5 * 1024 * 1024  # 5MB


class SignupSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ["full_name", "email", "phone_number", "password", "confirm_password"]

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("An account with this email already exists.")
        return value

    def validate_phone_number(self, value):
        # Stored in one standard shape (+27XXXXXXXXX). Contact matching only
        # compares the last 9 digits, so older numbers saved as 067... still match.
        normalized = normalize_sa_mobile((value or "").strip())
        if normalized is None:
            raise serializers.ValidationError(SA_MOBILE_MESSAGE)
        return normalized

    def validate_password(self, value):
        # Runs Django's configured password validators (minimum length,
        # not a common password, not all-numeric, not too close to the
        # user's own name/email) — real enforcement, not just the
        # "8 characters" check the Flutter form does client-side, which
        # anyone calling the API directly could skip.
        try:
            validate_password(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(list(exc.messages))
        return value

    def validate(self, data):
        if data["password"] != data["confirm_password"]:
            raise serializers.ValidationError({"confirm_password": "Passwords don't match."})
        return data

    def create(self, validated_data):
        validated_data.pop("confirm_password")
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class UserSerializer(serializers.ModelSerializer):
    profile_photo_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id", "full_name", "email", "phone_number",
            "profile_photo_url", "is_active_account", "date_joined_app",
            "show_last_seen",
        ]
        read_only_fields = fields

    def get_profile_photo_url(self, obj):
        if not obj.profile_photo:
            return None
        url = obj.profile_photo.url
        request = self.context.get("request")
        return request.build_absolute_uri(url) if request else url


class ProfilePhotoSerializer(serializers.Serializer):
    # ImageField checks that the upload really is an image (needs Pillow).
    photo = serializers.ImageField()

    def validate_photo(self, value):
        if value.size > MAX_PROFILE_PHOTO_BYTES:
            raise serializers.ValidationError("That picture is too large. Please choose one under 5MB.")
        return value


class ChangePasswordSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True)
    confirm_new_password = serializers.CharField(write_only=True)

    def validate_new_password(self, value):
        # Same real enforcement as signup — Django's configured password
        # validators, not just a client-side length check.
        try:
            validate_password(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(list(exc.messages))
        return value

    def validate(self, data):
        if data["new_password"] != data["confirm_new_password"]:
            raise serializers.ValidationError({"confirm_new_password": "Passwords don't match."})
        return data