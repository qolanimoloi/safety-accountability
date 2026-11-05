import math
from datetime import datetime, time, timedelta

from django.contrib.auth import get_user_model
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from notifications.models import Notification

from .models import (
    KINDS, MAX_MEMBERS, MAX_ZONES, Circle, CircleAlert, CircleMember, Proposal, ProposalVote, Zone,
)

User = get_user_model()
AUTH = [permissions.IsAuthenticated]
ZONE_ALERT_COOLDOWN = timedelta(minutes=30)


# ----------------------------------------------------------------- helpers

def _err(message, code=status.HTTP_400_BAD_REQUEST):
    return Response({"detail": message}, status=code)


def _name(user):
    return (user.full_name or user.email) if user else "Someone"


def _photo(user, request):
    f = getattr(user, "profile_photo", None)
    if f:
        try:
            return request.build_absolute_uri(f.url)
        except Exception:
            return None
    return None


def _hhmm(t):
    return t.strftime("%H:%M") if t else None


def _parse_hhmm(value):
    try:
        h, m = str(value).split(":")
        return time(int(h), int(m))
    except Exception:
        return None


def _distance_m(lat1, lng1, lat2, lng2):
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def _num(value):
    try:
        v = float(value)
    except (TypeError, ValueError):
        return None
    return v if math.isfinite(v) else None


def _coords(data):
    lat, lng = _num(data.get("latitude")), _num(data.get("longitude"))
    if lat is None or lng is None or not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
        return None
    return lat, lng


def _membership(circle, user, active_only=True):
    qs = CircleMember.objects.filter(circle=circle, user=user)
    if active_only:
        qs = qs.filter(status="active")
    return qs.first()


def _active_users(circle, exclude_user_id=None):
    qs = circle.memberships.filter(status="active").select_related("user")
    if exclude_user_id:
        qs = qs.exclude(user_id=exclude_user_id)
    return [m.user for m in qs]


def _tell(users, message, action="circle", circle=None, kind="alert"):
    for u in users:
        Notification.notify(u, kind, message, action=action, object_id=circle.id if circle else None)


def _can_set_rules(circle, member):
    return member.status == "active" and (circle.rules_mode == "vote" or member.role == "leader")


def _can_invite(circle, member):
    return _can_set_rules(circle, member)


# -------------------------------------------------------------- serializers

def _curfew_out(c):
    return {
        "enabled": c.curfew_enabled,
        "start": _hhmm(c.curfew_start),
        "end": _hhmm(c.curfew_end),
        "days": [int(d) for d in c.curfew_days.split(",") if d != ""],
        "grace_minutes": c.curfew_grace_minutes,
    }


def _zone_out(z):
    return {"id": z.id, "name": z.name, "latitude": z.lat, "longitude": z.lng, "radius_m": z.radius_m}


def _member_out(m, viewer, request):
    show_home = viewer is not None and (m.user_id == viewer.user_id or (viewer.role == "leader" and viewer.status == "active"))
    out = {
        "user_id": m.user_id,
        "name": _name(m.user),
        "photo_url": _photo(m.user, request),
        "role": m.role,
        "status": m.status,
        "is_me": viewer is not None and m.user_id == viewer.user_id,
        "home_set": m.home_set,
        "home": None,
    }
    if show_home and m.home_set:
        out["home"] = {"latitude": m.home_lat, "longitude": m.home_lng, "radius_m": m.home_radius_m}
    return out


def _circle_out(circle, viewer, request):
    members = [m for m in circle.memberships.all() if m.status in ("active", "invited")]
    return {
        "id": circle.id,
        "name": circle.name,
        "kind": circle.kind,
        "kind_label": circle.kind_label,
        "rules_mode": circle.rules_mode,
        "my_status": viewer.status,
        "my_role": viewer.role,
        "can_set_rules": _can_set_rules(circle, viewer),
        "can_invite": _can_invite(circle, viewer),
        "curfew": _curfew_out(circle),
        "zones": [_zone_out(z) for z in circle.zones.all()],
        "members": [_member_out(m, viewer, request) for m in members],
        "pending_proposals": circle.proposals.filter(status="pending").count() if viewer.status == "active" else 0,
        "my_home_set": viewer.home_set,
    }


def _load_circle(pk):
    return Circle.objects.prefetch_related("memberships__user", "zones").get(pk=pk)


def _proposal_out(p, request, my_id, active_n):
    votes = list(p.votes.all())
    yes = sum(1 for v in votes if v.agree)
    no = sum(1 for v in votes if not v.agree)
    mine = next((v.agree for v in votes if v.user_id == my_id), None)
    return {
        "id": p.id,
        "kind": p.kind,
        "payload": p.payload,
        "status": p.status,
        "proposer": _name(p.proposer),
        "yes": yes,
        "no": no,
        "needed": active_n // 2 + 1,
        "my_vote": mine,
        "created_at": p.created_at.isoformat(),
    }


# -------------------------------------------------------------------- rules

def _clean_curfew(data):
    enabled = bool(data.get("enabled", True))
    if not enabled:
        return {"enabled": False}, None
    start, end = _parse_hhmm(data.get("start")), _parse_hhmm(data.get("end"))
    if not start or not end:
        return None, "Choose a start and an end time for the curfew."
    if start == end:
        return None, "The curfew start and end times must be different."
    days = data.get("days")
    if not isinstance(days, list) or not days:
        return None, "Choose at least one day for the curfew."
    try:
        days = sorted({int(d) for d in days})
    except (TypeError, ValueError):
        return None, "Those curfew days are not valid."
    if any(d < 0 or d > 6 for d in days):
        return None, "Those curfew days are not valid."
    try:
        grace = int(data.get("grace_minutes", 15))
    except (TypeError, ValueError):
        return None, "The grace period must be a number of minutes."
    if grace < 0 or grace > 120:
        return None, "The grace period must be between 0 and 120 minutes."
    return {"enabled": True, "start": _hhmm(start), "end": _hhmm(end), "days": days, "grace_minutes": grace}, None


def _clean_zone(data):
    name = (data.get("name") or "").strip()
    c = _coords(data)
    try:
        radius = int(float(data.get("radius_m")))
    except (TypeError, ValueError):
        radius = None
    if not name or len(name) > 60:
        return None, "Give the place a name (up to 60 characters)."
    if c is None:
        return None, "Pick the place on the map."
    if radius is None or radius < 50 or radius > 5000:
        return None, "The radius must be between 50 m and 5 km."
    return {"name": name, "latitude": c[0], "longitude": c[1], "radius_m": radius}, None


def _apply_curfew(circle, p):
    if not p.get("enabled"):
        circle.curfew_enabled = False
    else:
        circle.curfew_enabled = True
        circle.curfew_start = _parse_hhmm(p["start"])
        circle.curfew_end = _parse_hhmm(p["end"])
        circle.curfew_days = ",".join(str(d) for d in p["days"])
        circle.curfew_grace_minutes = p["grace_minutes"]
    circle.save()


def _apply_zone_add(circle, p, user):
    if circle.zones.count() >= MAX_ZONES:
        return False
    Zone.objects.create(circle=circle, name=p["name"], lat=p["latitude"], lng=p["longitude"], radius_m=p["radius_m"], created_by=user)
    return True


def _describe(kind, p):
    if kind == "curfew":
        if not p.get("enabled"):
            return "turn the curfew off"
        return f"a curfew from {p['start']} to {p['end']}"
    if kind == "zone_add":
        return f"the restricted place \"{p['name']}\""
    return f"removing \"{p.get('name', 'a restricted place')}\" from the restricted places"


def _apply(circle, kind, payload, user):
    """Applies an approved rule. Returns True when it took effect."""
    if kind == "curfew":
        _apply_curfew(circle, payload)
        return True
    if kind == "zone_add":
        return _apply_zone_add(circle, payload, user)
    if kind == "zone_remove":
        circle.zones.filter(id=payload.get("zone_id")).delete()
        return True
    return False


def _resolve(proposal):
    circle = proposal.circle
    active_ids = set(circle.memberships.filter(status="active").values_list("user_id", flat=True))
    n = len(active_ids)
    votes = [v for v in proposal.votes.all() if v.user_id in active_ids]
    yes = sum(1 for v in votes if v.agree)
    no = sum(1 for v in votes if not v.agree)
    need = n // 2 + 1
    if yes >= need:
        ok = _apply(circle, proposal.kind, proposal.payload, proposal.proposer)
        proposal.status = "approved" if ok else "rejected"
        proposal.decided_at = timezone.now()
        proposal.save()
        what = _describe(proposal.kind, proposal.payload)
        if ok:
            _tell(_active_users(circle), f"{circle.name}: the group agreed on {what}.", circle=circle)
        return
    if no > n - need:
        proposal.status = "rejected"
        proposal.decided_at = timezone.now()
        proposal.save()
        _tell([proposal.proposer] if proposal.proposer else [], f"{circle.name}: the group did not agree on {_describe(proposal.kind, proposal.payload)}.", circle=circle)


def _submit_rule(request, circle, member, kind, payload):
    """Leaders apply directly in 'leader' circles; in 'vote' circles it becomes a proposal."""
    if not _can_set_rules(circle, member):
        return _err("Only a leader can change the rules in this circle.", status.HTTP_403_FORBIDDEN)
    with transaction.atomic():
        if circle.rules_mode == "leader":
            if not _apply(circle, kind, payload, request.user):
                return _err(f"A circle can have up to {MAX_ZONES} restricted places.")
            _tell(_active_users(circle, request.user.id), f"{circle.name}: {_name(request.user)} set {_describe(kind, payload)}.", circle=circle)
            return Response({"applied": True, "circle": _circle_out(_load_circle(circle.pk), member, request)})
        if kind == "zone_add" and circle.zones.count() >= MAX_ZONES:
            return _err(f"A circle can have up to {MAX_ZONES} restricted places.")
        proposal = Proposal.objects.create(circle=circle, proposer=request.user, kind=kind, payload=payload)
        ProposalVote.objects.create(proposal=proposal, user=request.user, agree=True)
        _tell(
            _active_users(circle, request.user.id),
            f"{circle.name}: {_name(request.user)} proposed {_describe(kind, payload)}. Open the circle to vote.",
            action="circle_vote", circle=circle,
        )
        _resolve(proposal)
        proposal.refresh_from_db()
    return Response({"applied": proposal.status == "approved", "proposal_status": proposal.status,
                     "circle": _circle_out(_load_circle(circle.pk), member, request)})


# ------------------------------------------------------------------- views

@api_view(["GET", "POST"])
@permission_classes(AUTH)
def circle_list_create(request):
    if request.method == "GET":
        mine = CircleMember.objects.filter(user=request.user, status__in=["active", "invited"]).values_list("circle_id", flat=True)
        circles = Circle.objects.filter(id__in=mine).prefetch_related("memberships__user", "zones").order_by("-created_at")
        out = []
        for c in circles:
            viewer = next(m for m in c.memberships.all() if m.user_id == request.user.id)
            out.append(_circle_out(c, viewer, request))
        return Response(out)

    name = (request.data.get("name") or "").strip()
    kind = request.data.get("kind") or ""
    if not name or len(name) > 60:
        return _err("Give the circle a name (up to 60 characters).")
    if kind not in KINDS:
        return _err("Choose a type of circle.")
    mode = KINDS[kind][1]
    if kind == "custom" and request.data.get("rules_mode") in ("leader", "vote"):
        mode = request.data["rules_mode"]
    with transaction.atomic():
        circle = Circle.objects.create(name=name, kind=kind, rules_mode=mode, created_by=request.user)
        CircleMember.objects.create(circle=circle, user=request.user, role="leader", status="active", joined_at=timezone.now())
    circle = _load_circle(circle.pk)
    return Response(_circle_out(circle, _membership(circle, request.user), request), status=status.HTTP_201_CREATED)


@api_view(["GET", "PATCH", "DELETE"])
@permission_classes(AUTH)
def circle_detail(request, pk):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user, active_only=False)
    if not me or me.status not in ("active", "invited"):
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        return Response(_circle_out(_load_circle(pk), me, request))

    if me.status != "active":
        return _err("Accept the invitation first.", status.HTTP_403_FORBIDDEN)

    if request.method == "PATCH":
        if me.role != "leader":
            return _err("Only a leader can rename the circle.", status.HTTP_403_FORBIDDEN)
        name = (request.data.get("name") or "").strip()
        if not name or len(name) > 60:
            return _err("Give the circle a name (up to 60 characters).")
        circle.name = name
        circle.save()
        return Response(_circle_out(_load_circle(pk), me, request))

    # DELETE
    others = circle.memberships.filter(status="active").exclude(user=request.user).count()
    if circle.rules_mode == "leader":
        if me.role != "leader":
            return _err("Only a leader can delete this circle.", status.HTTP_403_FORBIDDEN)
    elif others > 0:
        return _err("Other people are still in this circle. Leave it instead.", status.HTTP_403_FORBIDDEN)
    members = _active_users(circle, request.user.id)
    _tell(members, f"{_name(request.user)} deleted the circle \"{circle.name}\".", action="circle", circle=None)
    circle.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
@permission_classes(AUTH)
def circle_invite(request, pk):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user)
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)
    if not _can_invite(circle, me):
        return _err("Only a leader can invite people to this circle.", status.HTTP_403_FORBIDDEN)
    try:
        target_id = int(request.data.get("user_id"))
    except (TypeError, ValueError):
        return _err("Choose a person to invite.")
    if target_id == request.user.id:
        return _err("You are already in this circle.")
    target = User.objects.filter(pk=target_id).first()
    if not target:
        return _err("That person was not found.", status.HTTP_404_NOT_FOUND)
    if circle.memberships.filter(status__in=["active", "invited"]).count() >= MAX_MEMBERS:
        return _err(f"A circle can have up to {MAX_MEMBERS} people.")
    existing = circle.memberships.filter(user=target).first()
    if existing and existing.status in ("active", "invited"):
        return _err(f"{_name(target)} is already {'in this circle' if existing.status == 'active' else 'invited'}.")
    if existing:
        existing.status, existing.role, existing.invited_by = "invited", "member", request.user
        existing.home_lat = existing.home_lng = None
        existing.save()
    else:
        CircleMember.objects.create(circle=circle, user=target, status="invited", invited_by=request.user)
    Notification.notify(
        target, "alert",
        f"{_name(request.user)} invited you to the {circle.kind_label} circle \"{circle.name}\". Open it to see the rules before you decide.",
        action="circle_invite", object_id=circle.id,
    )
    return Response(_circle_out(_load_circle(pk), me, request), status=status.HTTP_201_CREATED)


@api_view(["POST"])
@permission_classes(AUTH)
def circle_respond(request, pk):
    circle = get_object_or_404(Circle, pk=pk)
    me = circle.memberships.filter(user=request.user, status="invited").first()
    if not me:
        return _err("There is no invitation for you here.", status.HTTP_404_NOT_FOUND)
    action = request.data.get("action")
    if action not in ("accept", "decline"):
        return _err("Choose accept or decline.")
    if action == "decline":
        me.status = "declined"
        me.save()
        return Response({"status": "declined"})
    me.status = "active"
    me.joined_at = timezone.now()
    me.save()
    _tell(_active_users(circle, request.user.id), f"{_name(request.user)} joined \"{circle.name}\".", circle=circle)
    circle = _load_circle(pk)
    return Response(_circle_out(circle, _membership(circle, request.user), request))


@api_view(["POST"])
@permission_classes(AUTH)
def circle_leave(request, pk):
    circle = get_object_or_404(Circle, pk=pk)
    me = circle.memberships.filter(user=request.user, status__in=["active", "invited"]).first()
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)
    was_active = me.status == "active"
    with transaction.atomic():
        me.delete()
        rest = list(circle.memberships.filter(status="active").order_by("joined_at", "id"))
        if not rest:
            circle.delete()
            return Response({"left": True, "deleted": True})
        if was_active and not any(m.role == "leader" for m in rest):
            rest[0].role = "leader"
            rest[0].save()
    if was_active:
        _tell([m.user for m in rest], f"{_name(request.user)} left \"{circle.name}\".", circle=circle)
    return Response({"left": True, "deleted": False})


@api_view(["POST"])
@permission_classes(AUTH)
def member_remove(request, pk, user_id):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user)
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)
    if circle.rules_mode != "leader" or me.role != "leader":
        return _err("Only a leader can remove people from this circle.", status.HTTP_403_FORBIDDEN)
    if user_id == request.user.id:
        return _err("Use Leave to leave the circle yourself.")
    target = circle.memberships.filter(user_id=user_id, status__in=["active", "invited"]).select_related("user").first()
    if not target:
        return _err("That person is not in this circle.", status.HTTP_404_NOT_FOUND)
    user = target.user
    target.delete()
    Notification.notify(user, "alert", f"You were removed from the circle \"{circle.name}\".", action="circle", object_id=None)
    return Response(_circle_out(_load_circle(pk), me, request))


@api_view(["POST"])
@permission_classes(AUTH)
def member_promote(request, pk, user_id):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user)
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)
    if me.role != "leader":
        return _err("Only a leader can make someone a leader.", status.HTTP_403_FORBIDDEN)
    target = circle.memberships.filter(user_id=user_id, status="active").first()
    if not target:
        return _err("That person is not in this circle.", status.HTTP_404_NOT_FOUND)
    target.role = "leader"
    target.save()
    Notification.notify(target.user, "alert", f"{_name(request.user)} made you a leader of \"{circle.name}\".", action="circle", object_id=circle.id)
    return Response(_circle_out(_load_circle(pk), me, request))


@api_view(["POST", "DELETE"])
@permission_classes(AUTH)
def my_home(request, pk):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user)
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)
    if request.method == "DELETE":
        me.home_lat = me.home_lng = None
        me.save()
        return Response(_circle_out(_load_circle(pk), me, request))
    c = _coords(request.data)
    if c is None:
        return _err("Pick your home on the map.")
    try:
        radius = int(float(request.data.get("radius_m", 150)))
    except (TypeError, ValueError):
        radius = 150
    if radius < 50 or radius > 500:
        return _err("The home area must be between 50 m and 500 m.")
    me.home_lat, me.home_lng, me.home_radius_m = c[0], c[1], radius
    me.save()
    return Response(_circle_out(_load_circle(pk), me, request))


@api_view(["PUT"])
@permission_classes(AUTH)
def circle_curfew(request, pk):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user)
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)
    payload, error = _clean_curfew(request.data)
    if error:
        return _err(error)
    return _submit_rule(request, circle, me, "curfew", payload)


@api_view(["POST"])
@permission_classes(AUTH)
def zone_create(request, pk):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user)
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)
    payload, error = _clean_zone(request.data)
    if error:
        return _err(error)
    return _submit_rule(request, circle, me, "zone_add", payload)


@api_view(["DELETE"])
@permission_classes(AUTH)
def zone_delete(request, pk, zone_id):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user)
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)
    zone = circle.zones.filter(pk=zone_id).first()
    if not zone:
        return _err("That place was not found.", status.HTTP_404_NOT_FOUND)
    return _submit_rule(request, circle, me, "zone_remove", {"zone_id": zone.id, "name": zone.name})


@api_view(["GET"])
@permission_classes(AUTH)
def proposal_list(request, pk):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user)
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)
    n = circle.memberships.filter(status="active").count()
    props = circle.proposals.select_related("proposer").prefetch_related("votes")[:20]
    return Response([_proposal_out(p, request, request.user.id, n) for p in props])


@api_view(["POST"])
@permission_classes(AUTH)
def proposal_vote(request, pk):
    proposal = get_object_or_404(Proposal, pk=pk)
    circle = proposal.circle
    me = _membership(circle, request.user)
    if not me:
        return _err("That proposal was not found.", status.HTTP_404_NOT_FOUND)
    agree = request.data.get("agree")
    if not isinstance(agree, bool):
        return _err("Say whether you agree.")
    if proposal.status != "pending":
        return _err("This vote is already finished.")
    with transaction.atomic():
        ProposalVote.objects.update_or_create(proposal=proposal, user=request.user, defaults={"agree": agree})
        _resolve(proposal)
    proposal = Proposal.objects.select_related("proposer").prefetch_related("votes").get(pk=pk)
    n = circle.memberships.filter(status="active").count()
    return Response(_proposal_out(proposal, request, request.user.id, n))


@api_view(["GET"])
@permission_classes(AUTH)
def monitor_rules(request):
    """Everything this phone needs to check the rules on its own."""
    mine = CircleMember.objects.filter(user=request.user, status="active").select_related("circle").prefetch_related("circle__zones")
    out = []
    for m in mine:
        c = m.circle
        out.append(
            {
                "circle_id": c.id,
                "name": c.name,
                "curfew": _curfew_out(c),
                "home": {"latitude": m.home_lat, "longitude": m.home_lng, "radius_m": m.home_radius_m} if m.home_set else None,
                "zones": [_zone_out(z) for z in c.zones.all()],
            }
        )
    return Response(out)


@api_view(["GET", "POST"])
@permission_classes(AUTH)
def circle_alerts(request, pk):
    circle = get_object_or_404(Circle, pk=pk)
    me = _membership(circle, request.user)
    if not me:
        return _err("That circle was not found.", status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        items = circle.alerts.select_related("user", "zone")[:30]
        return Response(
            [
                {
                    "id": a.id, "kind": a.kind, "user_id": a.user_id, "name": _name(a.user), "zone_name": a.zone_name,
                    "latitude": a.latitude, "longitude": a.longitude, "created_at": a.created_at.isoformat(),
                }
                for a in items
            ]
        )

    kind = request.data.get("kind")
    c = _coords(request.data)
    if kind not in ("curfew", "zone"):
        return _err("Unknown alert type.")
    if c is None:
        return _err("A location is needed to raise this alert.")
    lat, lng = c
    who = _name(request.user)
    maps = f"https://www.google.com/maps/search/?api=1&query={lat:.5f},{lng:.5f}"

    if kind == "curfew":
        if not circle.curfew_enabled:
            return _err("This circle has no curfew right now.", status.HTTP_409_CONFLICT)
        if not me.home_set:
            return _err("Set your home first.", status.HTTP_409_CONFLICT)
        if _distance_m(lat, lng, me.home_lat, me.home_lng) <= me.home_radius_m:
            return _err("You are at home, so there is nothing to report.", status.HTTP_409_CONFLICT)
        night = str(request.data.get("night") or "")
        try:
            datetime.strptime(night, "%Y-%m-%d")
        except ValueError:
            return _err("A date is needed for the curfew alert.")
        key = f"curfew:{night}"
        if CircleAlert.objects.filter(circle=circle, user=request.user, dedupe_key=key).exists():
            return Response({"duplicate": True})
        alert = CircleAlert.objects.create(circle=circle, user=request.user, kind="curfew", latitude=lat, longitude=lng, dedupe_key=key)
        text = f"{circle.name}: {who} is not home and it is past curfew. Last location: {maps}"
        mine = f"{circle.name}: your circle was told you are not home after curfew."
    else:
        zone = circle.zones.filter(pk=request.data.get("zone_id")).first()
        if not zone:
            return _err("That restricted place was not found.", status.HTTP_404_NOT_FOUND)
        if _distance_m(lat, lng, zone.lat, zone.lng) > zone.radius_m + 300:
            return _err("You are not at that place, so there is nothing to report.", status.HTTP_409_CONFLICT)
        recent = CircleAlert.objects.filter(circle=circle, user=request.user, zone=zone, created_at__gte=timezone.now() - ZONE_ALERT_COOLDOWN)
        if recent.exists():
            return Response({"duplicate": True})
        alert = CircleAlert.objects.create(circle=circle, user=request.user, kind="zone", zone=zone, zone_name=zone.name, latitude=lat, longitude=lng, dedupe_key=f"zone:{zone.id}")
        text = f"{circle.name}: {who} entered a restricted place: {zone.name}. Location: {maps}"
        mine = f"{circle.name}: your circle was told you entered \"{zone.name}\"."

    _tell(_active_users(circle, request.user.id), text, action="circle_alert", circle=circle)
    Notification.notify(request.user, "alert", mine, action="circle", object_id=circle.id)
    return Response({"duplicate": False, "id": alert.id}, status=status.HTTP_201_CREATED)