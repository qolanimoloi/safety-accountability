"""Small helpers shared by chat messages and community comments for emoji reactions."""

MAX_EMOJI_LENGTH = 16
MAX_NAMES_PER_EMOJI = 30


def clean_emoji(raw):
    """
    Returns the cleaned emoji, "" meaning "remove my reaction",
    or None when the value is not a usable emoji.
    """
    value = str(raw).strip() if raw is not None else ""
    if value == "":
        return ""
    if len(value) > MAX_EMOJI_LENGTH or any(ch.isspace() for ch in value):
        return None
    # Every emoji contains at least one non-ASCII character. Plain letters,
    # digits and punctuation are not accepted as a "reaction".
    if all(ord(ch) < 128 for ch in value):
        return None
    return value


def _photo_url(user, request):
    photo = getattr(user, "profile_photo", None)
    if not photo:
        return None
    url = photo.url
    return request.build_absolute_uri(url) if request else url


def summarize(reactions, user_id, request=None):
    """
    Turns reaction rows into what the app shows under a message or comment:
    [{"emoji": "👍", "count": 3, "mine": true, "users": [{"id", "name", "photo_url"}]}]
    Most used first. `reactions` should be prefetched (with user) by the caller.
    """
    counts, order, mine, people = {}, [], set(), {}
    for r in reactions:
        if r.emoji not in counts:
            counts[r.emoji] = 0
            order.append(r.emoji)
            people[r.emoji] = []
        counts[r.emoji] += 1
        if r.user_id == user_id:
            mine.add(r.emoji)
        if len(people[r.emoji]) < MAX_NAMES_PER_EMOJI and r.user is not None:
            people[r.emoji].append(
                {
                    "id": r.user_id,
                    "name": r.user.full_name or "Someone",
                    "photo_url": _photo_url(r.user, request),
                }
            )
    order.sort(key=lambda e: -counts[e])  # stable: ties keep first-reacted order
    return [{"emoji": e, "count": counts[e], "mine": e in mine, "users": people[e]} for e in order]


def apply_reaction(model, lookup, user, emoji):
    """
    One reaction per person per item.
      emoji == ""        -> remove the person's reaction
      same emoji again   -> remove it (tap to un-react, like WhatsApp)
      different emoji    -> replace it
      none yet           -> add it
    """
    existing = model.objects.filter(user=user, **lookup).first()
    if not emoji:
        if existing:
            existing.delete()
        return
    if existing:
        if existing.emoji == emoji:
            existing.delete()
        else:
            existing.emoji = emoji
            existing.save(update_fields=["emoji"])
        return
    model.objects.create(user=user, emoji=emoji, **lookup)