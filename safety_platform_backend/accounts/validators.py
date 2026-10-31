import re

SA_MOBILE_MESSAGE = (
    "Enter a valid South African mobile number, for example 071 234 5678 or +27 71 234 5678."
)


def normalize_sa_mobile(raw):
    """Return the number as +27XXXXXXXXX, or None if it is not a valid SA mobile number."""
    s = re.sub(r"[\s\-\(\)\.]", "", raw or "")
    if s.startswith("+27"):
        s = "0" + s[3:]
    elif s.startswith("0027"):
        s = "0" + s[4:]
    elif s.startswith("27") and len(s) == 11:
        s = "0" + s[2:]
    if not re.fullmatch(r"0\d{9}", s):
        return None
    # Mobile ranges: 06x, 07x, 081-085. Excludes 080 (toll free), 086/087 (service and VoIP).
    if not re.fullmatch(r"0(6\d|7\d|8[1-5])\d{7}", s):
        return None
    subscriber = s[3:]  # the 7 digits after the network prefix
    if len(set(subscriber)) == 1:  # e.g. 071 111 1111
        return None
    return "+27" + s[1:]