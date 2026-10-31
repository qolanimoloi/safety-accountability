from .models import PostMedia, ALLOWED_IMAGE_EXTENSIONS, ALLOWED_VIDEO_EXTENSIONS, MAX_POST_MEDIA_SIZE_BYTES
from rest_framework import serializers
from .models import CommunityPost, PostComment, PostReport


class PostCommentSerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()
    author_id = serializers.SerializerMethodField()

    class Meta:
        model = PostComment
        fields = ["id", "author_id", "author_name", "content", "created_at"]
        read_only_fields = fields

    def get_author_name(self, obj):
        return obj.author.full_name if obj.author else "Unknown"

    def get_author_id(self, obj):
        return obj.author_id


class PostCommentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostComment
        fields = ["content"]


class PostMediaSerializer(serializers.ModelSerializer):
    file = serializers.SerializerMethodField()

    class Meta:
        model = PostMedia
        fields = ["id", "file", "media_type", "order"]

    def get_file(self, obj):
        request = self.context.get("request")
        url = obj.file.url
        return request.build_absolute_uri(url) if request else url


class CommunityPostSerializer(serializers.ModelSerializer):
    """
    What the feed (GET /api/community/posts/) returns. author_name/
    author_avatar are derived server-side rather than trusted from the
    client, same reasoning as is_official — a user can't post pretending
    to be someone else.
    """

    author_name = serializers.SerializerMethodField()
    author_avatar = serializers.SerializerMethodField()
    author_id = serializers.SerializerMethodField()
    author_photo = serializers.SerializerMethodField()
    post_type_display = serializers.CharField(source="get_post_type_display", read_only=True)
    category_display = serializers.CharField(source="get_category_display", read_only=True)
    likes_count = serializers.IntegerField(read_only=True)
    comments_count = serializers.IntegerField(read_only=True)
    shares_count = serializers.IntegerField(read_only=True)
    is_trending = serializers.BooleanField(read_only=True)
    media = PostMediaSerializer(many=True, read_only=True)
    distance_km = serializers.SerializerMethodField()
    liked_by_me = serializers.SerializerMethodField()

    class Meta:
        model = CommunityPost
        fields = [
            "id", "author_name", "author_avatar", "author_id", "author_photo", "post_type", "post_type_display",
            "category", "category_display", "content", "media",
            "location_description", "latitude", "longitude",
            "is_official", "is_quick_alert", "created_at",
            "likes_count", "comments_count", "shares_count", "is_trending",
            "distance_km", "liked_by_me",
        ]
        read_only_fields = [f for f in fields if f != "content"]

    def get_author_name(self, obj):
        return obj.author.full_name if obj.author else "Unknown"

    def get_author_avatar(self, obj):
        # Matches the mock's two-letter avatar initials (e.g. "Sarah
        # Johnson" -> "SJ") rather than requiring a real uploaded photo.
        if not obj.author or not obj.author.full_name:
            return "?"
        parts = obj.author.full_name.split()
        return "".join(p[0].upper() for p in parts[:2])

    def get_author_id(self, obj):
        return obj.author_id

    def get_author_photo(self, obj):
        photo = getattr(obj.author, "profile_photo", None) if obj.author else None
        if not photo:
            return None
        url = photo.url
        request = self.context.get("request")
        return request.build_absolute_uri(url) if request else url

    def get_distance_km(self, obj):
        request = self.context.get("request")
        lat = request.query_params.get("lat") if request else None
        lng = request.query_params.get("lng") if request else None
        return obj.distance_km_from(lat, lng)

    def get_liked_by_me(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        return obj.reactions.filter(user=request.user).exists()


class CommunityPostCreateSerializer(serializers.ModelSerializer):
    media = serializers.ListField(
        child=serializers.FileField(), required=False, write_only=True
    )

    class Meta:
        model = CommunityPost
        fields = ["post_type", "category", "content", "location_description", "latitude", "longitude", "media"]

    def validate_media(self, value):
        for f in value:
            ext = f.name.rsplit(".", 1)[-1].lower() if "." in f.name else ""
            if ext not in ALLOWED_IMAGE_EXTENSIONS | ALLOWED_VIDEO_EXTENSIONS:
                raise serializers.ValidationError(f"Unsupported file type: {f.name}")
            if f.size > MAX_POST_MEDIA_SIZE_BYTES:
                raise serializers.ValidationError(f"{f.name} is too large (max 60MB).")
        return value

    def create(self, validated_data):
        media_files = validated_data.pop("media", [])
        post = super().create(validated_data)
        for index, f in enumerate(media_files):
            ext = f.name.rsplit(".", 1)[-1].lower() if "." in f.name else ""
            media_type = "video" if ext in ALLOWED_VIDEO_EXTENSIONS else "image"
            PostMedia.objects.create(
                post=post,
                file=f,
                media_type=media_type,
                original_filename=f.name,
                content_type=getattr(f, "content_type", "") or "",
                size_bytes=f.size,
                order=index,
            )
        return post


class PostReportCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostReport
        fields = ["reason", "details"]