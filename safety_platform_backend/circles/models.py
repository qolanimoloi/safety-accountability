from django.conf import settings
from django.db import models

# kind -> (label, rules_mode). "leader": only leaders set rules.
# "vote": anyone can propose a rule and the group must agree.
KINDS = {
    "family": ("Family", "leader"),
    "children": ("Children", "leader"),
    "friends": ("Friend group", "vote"),
    "roommates": ("Roommates", "vote"),
    "partners": ("Partners", "vote"),
    "colleagues": ("Colleagues", "vote"),
    "neighbours": ("Neighbours", "vote"),
    "students": ("Students", "vote"),
    "travel": ("Travel group", "vote"),
    "custom": ("Custom", "vote"),
}
KIND_CHOICES = [(k, v[0]) for k, v in KINDS.items()]

MAX_MEMBERS = 30
MAX_ZONES = 10


class Circle(models.Model):
    name = models.CharField(max_length=60)
    kind = models.CharField(max_length=20, choices=KIND_CHOICES, default="family")
    rules_mode = models.CharField(max_length=10, default="leader")  # leader | vote
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="circles_created")
    created_at = models.DateTimeField(auto_now_add=True)

    # Curfew. Times are local clock times on the members' phones. days = "0,1,2,..." (Monday=0).
    curfew_enabled = models.BooleanField(default=False)
    curfew_start = models.TimeField(null=True, blank=True)  # e.g. 21:00
    curfew_end = models.TimeField(null=True, blank=True)    # e.g. 05:00 (may be after midnight)
    curfew_days = models.CharField(max_length=20, default="0,1,2,3,4,5,6")
    curfew_grace_minutes = models.PositiveSmallIntegerField(default=15)

    def __str__(self):
        return self.name

    @property
    def kind_label(self):
        return KINDS.get(self.kind, (self.kind, ""))[0]


class CircleMember(models.Model):
    ROLE = [("leader", "Leader"), ("member", "Member")]
    STATUS = [("invited", "Invited"), ("active", "Active"), ("declined", "Declined")]

    circle = models.ForeignKey(Circle, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="circle_memberships")
    role = models.CharField(max_length=10, choices=ROLE, default="member")
    status = models.CharField(max_length=10, choices=STATUS, default="invited")
    invited_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name="+")
    created_at = models.DateTimeField(auto_now_add=True)
    joined_at = models.DateTimeField(null=True, blank=True)

    # The member's own home. Only they (and leaders of the circle) can see the coordinates.
    home_lat = models.FloatField(null=True, blank=True)
    home_lng = models.FloatField(null=True, blank=True)
    home_radius_m = models.PositiveIntegerField(default=150)

    class Meta:
        unique_together = ("circle", "user")
        ordering = ["created_at", "id"]

    @property
    def home_set(self):
        return self.home_lat is not None and self.home_lng is not None


class Zone(models.Model):
    circle = models.ForeignKey(Circle, on_delete=models.CASCADE, related_name="zones")
    name = models.CharField(max_length=60)
    lat = models.FloatField()
    lng = models.FloatField()
    radius_m = models.PositiveIntegerField(default=300)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at", "id"]


class Proposal(models.Model):
    """A rule change in a 'vote' circle. Applied when a majority of active members agree."""
    KINDS = [("curfew", "Curfew"), ("zone_add", "Add restricted place"), ("zone_remove", "Remove restricted place")]
    STATUS = [("pending", "Pending"), ("approved", "Approved"), ("rejected", "Rejected")]

    circle = models.ForeignKey(Circle, on_delete=models.CASCADE, related_name="proposals")
    proposer = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name="+")
    kind = models.CharField(max_length=20, choices=KINDS)
    payload = models.JSONField(default=dict)
    status = models.CharField(max_length=10, choices=STATUS, default="pending")
    created_at = models.DateTimeField(auto_now_add=True)
    decided_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]


class ProposalVote(models.Model):
    proposal = models.ForeignKey(Proposal, on_delete=models.CASCADE, related_name="votes")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="+")
    agree = models.BooleanField()

    class Meta:
        unique_together = ("proposal", "user")


class CircleAlert(models.Model):
    KINDS = [("curfew", "Past curfew, not home"), ("zone", "Entered a restricted place")]

    circle = models.ForeignKey(Circle, on_delete=models.CASCADE, related_name="alerts")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="circle_alerts")
    kind = models.CharField(max_length=10, choices=KINDS)
    zone = models.ForeignKey(Zone, null=True, blank=True, on_delete=models.SET_NULL)
    zone_name = models.CharField(max_length=60, blank=True, default="")
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    dedupe_key = models.CharField(max_length=60, blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at", "-id"]