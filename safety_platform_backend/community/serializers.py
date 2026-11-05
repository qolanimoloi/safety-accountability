from rest_framework import serializers

from accounts.reactions import summarize

from .models import (
    ALLOWED_IMAGE_EXTENSIONS,
    ALLOWED_VIDEO_EXTENSIONS,
    COMMENT_IMAGE_EXTENSIONS,
    COMMENT_VIDEO_EXTENSIONS,
    MAX_COMMENT_IMAGE_BYTES,
    MAX_COMMENT_VIDEO_BYTES,
    MAX_POST_MEDIA_SIZE_BYTES,
    CommunityPost,
    PostComment,
    PostMedia,
    PostReport,
)


def _file_ext(name):
    return name.rsplit(".", 1)[-1].lower() if "." in name else ""


def _photo_url(user, request):
    photo = getattr(user, "profile_photo", None) if user else None
    if not photo:
        return None
    url = photo.url
    return request.build_absolute_uri(url) if request else url


class PostCommentSerializer(serializers.ModelSerializer):
    author_name = serializers.SerializerMethodField()
    author_id = serializers.SerializerMethodField()
    author_photo = serializers.SerializerMethodField()
    media_url = serializers.SerializerMethodField()
    reactions = serializers.SerializerMethodField()

    class Meta:
        model = PostComment
        fields = [
            "id", "author_id", "author_name", "author_photo", "content",
            "sticker", "media_url", "media_type", "reactions", "created_at",
        ]
        read_only_fields = fields

    def get_author_name(self, obj):
        return obj.author.full_name if obj.author else "Unknown"

    def get_author_id(self, obj):
        return obj.author_id

    def get_author_photo(self, obj):
        return _photo_url(obj.author, self.context.get("request"))

    def get_media_url(self, obj):
        if not obj.media:
            return None
        url = obj.media.url
        request = self.context.get("request")
        return request.build_absolute_uri(url) if request else url

    def get_reactions(self, obj):
        request = self.context.get("request")
        user_id = request.user.id if request else None
        return summarize(obj.reactions.all(), user_id, request)


class PostCommentCreateSerializer(serializers.ModelSerializer):
    content = serializers.CharField(required=False, allow_blank=True, max_length=2000)
    sticker = serializers.CharField(required=False, allow_blank=True, max_length=32)
    media = serializers.FileField(required=False, allow_null=True)

    class Meta:
        model = PostComment
        fields = ["content", "sticker", "media"]

    def validate_sticker(self, value):
        value = value.strip()
        if any(ch in value for ch in "\r\n\t"):
            raise serializers.ValidationError("That sticker is not valid.")
        return value

    def validate_media(self, f):
        if f is None:
            return f
        ext = _file_ext(f.name)
        if ext in COMMENT_IMAGE_EXTENSIONS:
            if f.size > MAX_COMMENT_IMAGE_BYTES:
                raise serializers.ValidationError("That picture is too large. Please choose one under 10MB.")
        elif ext in COMMENT_VIDEO_EXTENSIONS:
            if f.size > MAX_COMMENT_VIDEO_BYTES:
                raise serializers.ValidationError("That video is too large. Please choose one under 30MB.")
        else:
            raise serializers.ValidationError("Only pictures (JPG, PNG, GIF, WEBP) and videos (MP4, MOV) can be added.")
        return f

    def validate(self, data):
        content = (data.get("content") or "").strip()
        if not content and not data.get("sticker") and not data.get("media"):
            raise serializers.ValidationError({"content": "Write something, or add a sticker, picture or video."})
        data["content"] = content
        return data

    def create(self, validated_data):
        media = validated_data.get("media")
        if media:
            validated_data["media_type"] = "video" if _file_ext(media.name) in COMMENT_VIDEO_EXTENSIONS else "image"
        return super().create(validated_data)


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
    shared_from = serializers.SerializerMethodField()

    class Meta:
        model = CommunityPost
        fields = [
            "id", "author_name", "author_avatar", "author_id", "author_photo", "post_type", "post_type_display",
            "category", "category_display", "content", "media",
            "location_description", "latitude", "longitude",
            "is_official", "is_quick_alert", "is_repost", "shared_from", "created_at",
            "likes_count", "comments_count", "shares_count", "is_trending",
            "distance_km", "liked_by_me",
        ]
        read_only_fields = [f for f in fields if f != "content"]

    def get_author_name(self, obj):
        return obj.author.full_name if obj.author else "Unknown"

    def get_author_avatar(self, obj):
        if not obj.author or not obj.author.full_name:
            return "?"
        parts = obj.author.full_name.split()
        return "".join(p[0].upper() for p in parts[:2])

    def get_author_id(self, obj):
        return obj.author_id

    def get_author_photo(self, obj):
        return _photo_url(obj.author, self.context.get("request"))

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

    def get_shared_from(self, obj):
        """The original post inside a repost (None for ordinary posts)."""
        if not obj.is_repost:
            return None
        original = obj.shared_from
        if original is None or original.status != "published":
            return {"unavailable": True}
        request = self.context.get("request")
        return {
            "unavailable": False,
            "id": original.id,
            "author_id": original.author_id,
            "author_name": original.author.full_name if original.author else "Unknown",
            "author_photo": _photo_url(original.author, request),
            "is_official": original.is_official,
            "category_display": original.get_category_display(),
            "content": original.content,
            "created_at": original.created_at.isoformat(),
            "media": PostMediaSerializer(original.media.all(), many=True, context=self.context).data,
        }


class CommunityPostCreateSerializer(serializers.ModelSerializer):
    media = serializers.ListField(child=serializers.FileField(), required=False, write_only=True)

    class Meta:
        model = CommunityPost
        fields = ["post_type", "category", "content", "location_description", "latitude", "longitude", "media"]

    def validate_media(self, value):
        for f in value:
            ext = _file_ext(f.name)
            if ext not in ALLOWED_IMAGE_EXTENSIONS | ALLOWED_VIDEO_EXTENSIONS:
                raise serializers.ValidationError(f"Unsupported file type: {f.name}")
            if f.size > MAX_POST_MEDIA_SIZE_BYTES:
                raise serializers.ValidationError(f"{f.name} is too large (max 60MB).")
        return value

    def create(self, validated_data):
        media_files = validated_data.pop("media", [])
        post = super().create(validated_data)
        for index, f in enumerate(media_files):
            ext = _file_ext(f.name)
            media_type = "video" if ext in ALLOWED_VIDEO_EXTENSIONS else "image"
            PostMedia.objects.create(
                post=post, file=f, media_type=media_type, original_filename=f.name,
                content_type=getattr(f, "content_type", "") or "", size_bytes=f.size, order=index,
            )
        return post


class PostReportCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = PostReport
        fields = ["reason", "details"]