from rest_framework import serializers
from .models import NewsPost


class NewsPostSerializer(serializers.ModelSerializer):
    category_display = serializers.CharField(source="get_category_display", read_only=True)
    posted_by_name = serializers.SerializerMethodField()

    class Meta:
        model = NewsPost
        fields = ["id", "title", "body", "category", "category_display", "posted_by_name", "created_at"]
        read_only_fields = fields

    def get_posted_by_name(self, obj):
        if not obj.posted_by:
            return "Admin"
        return obj.posted_by.full_name or obj.posted_by.email