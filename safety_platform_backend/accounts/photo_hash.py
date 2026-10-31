from PIL import Image, ImageOps

HASH_SIZE = 8
# Two pictures whose fingerprints differ in this many bits or fewer (out of 64)
# are treated as the same picture (this catches resized and re-saved copies).
SAME_PICTURE_MAX_DISTANCE = 5


def dhash_hex(fileobj):
    """
    Return a 16-character fingerprint of the picture (a "difference hash").
    The same photo, resized or re-compressed, gives (almost) the same value.
    """
    fileobj.seek(0)
    with Image.open(fileobj) as img:
        img = ImageOps.exif_transpose(img)
        img = img.convert("L").resize((HASH_SIZE + 1, HASH_SIZE), Image.LANCZOS)
        pixels = img.tobytes()
    fileobj.seek(0)

    bits = 0
    for row in range(HASH_SIZE):
        base = row * (HASH_SIZE + 1)
        for col in range(HASH_SIZE):
            bits = (bits << 1) | (1 if pixels[base + col] > pixels[base + col + 1] else 0)
    return f"{bits:016x}"


def hamming_distance(hash_a, hash_b):
    return bin(int(hash_a, 16) ^ int(hash_b, 16)).count("1")


def is_same_picture(hash_a, hash_b):
    try:
        return hamming_distance(hash_a, hash_b) <= SAME_PICTURE_MAX_DISTANCE
    except ValueError:
        return False