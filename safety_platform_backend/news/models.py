from django.conf import settings
from django.db import models


class NewsPost(models.Model):
    """
    Backs the "Community Updates" feed on reports_page.dart — admin-authored
    news, alerts and safety tips shown to every app user. Distinct from
    community.CommunityPost (the Facebook-like user feed, where users post)
    and reports.AnonymousReport (anonymous incident reports) — this is
    pure admin-to-everyone broadcast content, matching the three
    categories already used client-side: stats, alert, tip.
    """

    CATEGORY_CHOICES = [
        ("stats", "Stats"),
        ("alert", "Alert"),
        ("tip", "Safety Tip"),
    ]

    title = models.CharField(max_length=200)
    body = models.TextField()
    category = models.CharField(max_length=10, choices=CATEGORY_CHOICES, default="tip")
    posted_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="news_posts")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"[{self.get_category_display()}] {self.title}"