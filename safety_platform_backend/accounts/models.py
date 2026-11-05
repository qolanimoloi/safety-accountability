from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.models import AbstractUser
from django.db import models


class UserManager(BaseUserManager):
    """
    Django's default UserManager hard-codes `username` as the first
    positional argument to create_user/create_superuser, which breaks
    `createsuperuser` the moment USERNAME_FIELD is changed to "email"
    (it was: `TypeError: create_superuser() missing 1 required
    positional argument: 'username'`). This manager replaces it so both
    commands work off email instead, matching how the app actually
    signs people up (no username field anywhere in auth_page.dart).
    """

    use_in_migrations = True

    def _create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError("Users must have an email address.")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_dashboard_admin", True)
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")
        return self._create_user(email, password, **extra_fields)


def profile_photo_upload_path(instance, filename):
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "jpg"
    return f"profile_photos/user_{instance.pk or 'new'}.{ext}"


class User(AbstractUser):
    """
    Custom user model for everyone who signs up through the Flutter app
    (auth_page.dart collects: Full Name, Email, Phone, Password).

    We extend AbstractUser instead of writing one from scratch so we keep
    Django's battle-tested password hashing, permissions, and the ability
    for staff to log into the web dashboard with the same model.

    username stays (inherited) but email is what the app actually signs
    up with, so it's unique and used to identify app accounts in the
    dashboard. full_name is stored as one field because that's how the
    signup form collects it, rather than forcing first/last name apart.
    """

    full_name = models.CharField(max_length=150, blank=True)
    email = models.EmailField(unique=True)
    phone_number = models.CharField(max_length=20, blank=True)

    # Optional profile picture. When empty the app shows the person's initials.
    profile_photo = models.ImageField(upload_to=profile_photo_upload_path, null=True, blank=True)

    # Fingerprint of the profile picture, used to stop the same picture being
    # used on two accounts. Empty when there is no picture.
    photo_hash = models.CharField(max_length=16, blank=True, default="", editable=False)

    # When the person last used the app (saved automatically, at most once a
    # minute) and whether other people may see it.
    last_seen = models.DateTimeField(null=True, blank=True, editable=False)
    show_last_seen = models.BooleanField(
        default=True,
        help_text="Lets other people see when this person was last active.",
    )

    # Staff who can log into the web admin dashboard vs. ordinary app
    # users. is_staff (inherited) already gates Django admin; this is a
    # clearer, dashboard-specific flag so "who can see the dashboard"
    # isn't tangled up with Django's own /admin/ permissions.
    is_dashboard_admin = models.BooleanField(
        default=False,
        help_text="Can log into the web admin dashboard.",
    )

    is_active_account = models.BooleanField(
        default=True,
        help_text="Lets an admin deactivate an account without deleting it.",
    )

    date_joined_app = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = UserManager()

    def save(self, *args, **kwargs):
        # The app's signup form never asks for a "username" — only
        # full name, email, phone, password. We still get the inherited
        # `username` field from AbstractUser (Django's permission system
        # expects it to exist), so auto-fill it from the email rather
        # than exposing a field nothing in the app collects.
        if not self.username:
            self.username = self.email
        super().save(*args, **kwargs)

    def __str__(self):
        return self.full_name or self.email