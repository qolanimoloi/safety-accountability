import math

from django.conf import settings
from django.db import models
from django.utils import timezone

TRENDING_ENGAGEMENT_THRESHOLD = 50  # likes + comments + shares at/above this → shown as "Trending" in the app


def post_image_upload_path(instance, filename):
    return f"community_posts/{instance.pk or 'new'}/{filename}"


def post_media_upload_path(instance, filename):
    return f"community_posts/{instance.post_id or 'new'}/{filename}"


MAX_POST_MEDIA_SIZE_BYTES = 60 * 1024 * 1024  # 60MB, matches settings upload limits
ALLOWED_IMAGE_EXTENSIONS = {"jpg", "jpeg", "png"}
ALLOWED_VIDEO_EXTENSIONS = {"mp4", "mov"}


class CommunityPost(models.Model):
    """
    Backs community_page.dart. A few things are deliberately different
    from the Flutter mock, by design, per what was asked for this module:

    - is_official / "Verified" badge: true only when the author is a
      dashboard admin at post time, so a user can never fake it.
    - status: lets an admin hide or remove a post after review — the
      mock has no concept of moderation at all.
    - is_trending is computed from real engagement (see property below)
      instead of being a flag the client sets itself.
    - latitude/longitude are real coordinates so "Nearby" and "X km
      away" can be computed server-side instead of hardcoded per post.
    """

    POST_TYPE_CHOICES = [
        ("alert", "Alert"),
        ("warning", "Warning"),
        ("wanted", "Wanted"),
    ]

    CATEGORY_CHOICES = [
        ("general_alert", "General Alert"),
        ("stolen_vehicle", "Stolen Vehicle"),
        ("break_in", "Break-In"),
        ("missing_person", "Missing Person"),
        ("wanted_person", "Wanted Person"),
        ("suspicious_activity", "Suspicious Activity"),
        ("stolen_goods", "Stolen Goods"),
        ("vandalism", "Vandalism"),
    ]

    STATUS_CHOICES = [
        ("published", "Published"),
        ("hidden", "Hidden by admin"),
        ("removed", "Removed by admin"),
    ]

    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="community_posts",
    )

    post_type = models.CharField(max_length=10, choices=POST_TYPE_CHOICES, default="alert")
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES, default="general_alert")
    content = models.TextField()
   

    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    location_description = models.CharField(max_length=255, blank=True)

    # Set automatically in the serializer at creation time — never
    # settable directly by the client, so a regular user can't post as
    # "verified" just by sending is_official: true.
    is_official = models.BooleanField(default=False)

    # True for posts created via the "Quick Alert" FAB — lets the
    # dashboard and feed distinguish an urgent one-tap alert from an
    # ordinary composed post, even though both are CommunityPost rows.
    is_quick_alert = models.BooleanField(default=False)

    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default="published")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        author_label = self.author.full_name if self.author else "Unknown"
        return f"{author_label}: {self.content[:40]}"

    @property
    def likes_count(self):
        return self.reactions.count()

    @property
    def comments_count(self):
        return self.comments.count()

    @property
    def shares_count(self):
        return self.shares.count()

    @property
    def reports_count(self):
        return self.reports.count()

    @property
    def is_trending(self):
        return (self.likes_count + self.comments_count + self.shares_count) >= TRENDING_ENGAGEMENT_THRESHOLD

    @property
    def media_count(self):
        return self.media.count()

    @property
    def thumbnail(self):
        """First image attached to the post, used for the dashboard table."""
        return self.media.filter(media_type="image").order_by("order").first()

    def distance_km_from(self, lat, lng):
        """Haversine distance in km from a given point, or None if this post has no coordinates."""
        if self.latitude is None or self.longitude is None or lat is None or lng is None:
            return None
        lat1, lng1, lat2, lng2 = map(float, [lat, lng, self.latitude, self.longitude])
        r = 6371.0  # Earth radius, km
        phi1, phi2 = math.radians(lat1), math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlambda = math.radians(lng2 - lng1)
        a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
        return round(r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)), 1)

class PostMedia(models.Model):
    MEDIA_TYPE_CHOICES = (
        ("image", "Image"),
        ("video", "Video"),
    )

    post = models.ForeignKey(CommunityPost, related_name="media", on_delete=models.CASCADE)
    file = models.FileField(upload_to=post_media_upload_path)
    media_type = models.CharField(max_length=10, choices=MEDIA_TYPE_CHOICES)
    original_filename = models.CharField(max_length=255, blank=True)
    content_type = models.CharField(max_length=100, blank=True)
    size_bytes = models.PositiveIntegerField(default=0)
    order = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["order", "created_at"]

    def __str__(self):
        return f"{self.media_type} for post #{self.post_id}"

class PostReaction(models.Model):
    """One "Support" (like) per user per post — replaces the mock's
    unlimited-tap counter with something an admin can actually audit."""

    post = models.ForeignKey(CommunityPost, related_name="reactions", on_delete=models.CASCADE)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("post", "user")


class PostComment(models.Model):
    """The mock shows a comment COUNT with no actual comments anywhere —
    this is the real thing behind that number."""

    post = models.ForeignKey(CommunityPost, related_name="comments", on_delete=models.CASCADE)
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]


class PostShare(models.Model):
    """A log, not just a counter — lets an admin see who shared what,
    useful for tracing how a (mis)information post spread."""

    post = models.ForeignKey(CommunityPost, related_name="shares", on_delete=models.CASCADE)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class PostReport(models.Model):
    """
    The "Report" button in the Flutter card currently does nothing.
    This is what makes it real, and what "admin sees what users are
    posting" actually means in practice — a moderation queue, not just
    a read-only feed.
    """

    REASON_CHOICES = [
        ("false_information", "False information"),
        ("harassment", "Harassment or abuse"),
        ("spam", "Spam"),
        ("inappropriate", "Inappropriate content"),
        ("other", "Other"),
    ]

    post = models.ForeignKey(CommunityPost, related_name="reports", on_delete=models.CASCADE)
    reporter = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    reason = models.CharField(max_length=30, choices=REASON_CHOICES)
    details = models.TextField(blank=True)

    resolved = models.BooleanField(default=False)
    admin_notes = models.TextField(blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def mark_resolved(self, notes=""):
        self.resolved = True
        self.resolved_at = timezone.now()
        if notes:
            self.admin_notes = notes
        self.save()