"""Board sprites at 2x resolution (Sprite2D nodes use scale 0.5): station pins, tokens,
last-seen marker, vehicles. Drawn 4x supersampled for clean anti-aliased edges.
Run from the project root: python3 tools/generate_board_sprites.py
"""
import math
from PIL import Image, ImageDraw, ImageFilter

SS = 4  # supersampling
OUT = "game/assets/sprites/single/shared/"

def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))

def save(img, name):
    w, h = img.size
    img.resize((w // SS, h // SS), Image.LANCZOS).save(OUT + name)

def S(v):
    return [x * SS for x in v] if isinstance(v, (list, tuple)) else v * SS

def shadow(img, blur, alpha):
    a = img.split()[3].point(lambda p: int(p * alpha))
    sh = Image.new("RGBA", img.size, (10, 14, 30, 0))
    sh.putalpha(a)
    return sh.filter(ImageFilter.GaussianBlur(blur * SS))

def pin_shape(draw, cx, cy, r, tip_y, fill, outline=None, ow=0):
    # Teardrop: circle head + tangent lines down to the tip.
    d = tip_y - cy
    ang = math.asin(min(0.999, r / d))
    tx = r * math.cos(ang)
    ty = r * math.sin(ang)
    poly = [(cx - tx, cy + ty), (cx, tip_y), (cx + tx, cy + ty)]
    if outline:
        o = ow
        draw.ellipse(S([cx - r - o, cy - r - o, cx + r + o, cy + r + o]), fill=outline)
        dd = tip_y + o * 1.6 - cy
        a2 = math.asin(min(0.999, (r + o) / dd))
        draw.polygon([tuple(S(p)) for p in [(cx - (r + o) * math.cos(a2), cy + (r + o) * math.sin(a2)), (cx, tip_y + o * 1.6), (cx + (r + o) * math.cos(a2), cy + (r + o) * math.sin(a2))]], fill=outline)
    draw.ellipse(S([cx - r, cy - r, cx + r, cy + r]), fill=fill)
    draw.polygon([tuple(S(p)) for p in poly], fill=fill)

# Station pin: 56x80 texture, tip at (28, 76), head centre (28, 28), radius 21 (2x units).
PW, PH, HC, HR, TIP = 56, 80, (28, 29), 20, 76
INK = (24, 30, 48, 255)

def station_pin():
    img = canvas(PW, PH)
    d = ImageDraw.Draw(img)
    pin_shape(d, HC[0], HC[1], HR, TIP, (255, 255, 255, 255), INK, 2.6)
    # ground shadow under the tip
    sh = canvas(PW, PH)
    ImageDraw.Draw(sh).ellipse(S([HC[0] - 9, TIP - 3, HC[0] + 9, TIP + 3]), fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(1.5 * SS))
    out = Image.alpha_composite(sh, Image.alpha_composite(shadow(img, 2.5, 0.35), img))
    save(out, "city/map_pin.png")

def head_part(name, color, box):
    # Coloured part of the pin head, clipped to the inner circle.
    img = canvas(PW, PH)
    mask = canvas(PW, PH)
    ImageDraw.Draw(mask).ellipse(S([HC[0] - HR + 1.2, HC[1] - HR + 1.2, HC[0] + HR - 1.2, HC[1] + HR - 1.2]), fill=(255, 255, 255, 255))
    ImageDraw.Draw(img).rectangle(S(box), fill=color)
    img.putalpha(Image.composite(img.split()[3], Image.new("L", img.size, 0), mask.split()[3]))
    save(img, name)

def pin_highlight():
    w, h = 80, 104
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    pin_shape(d, 40, 41, HR + 7, 100, (255, 214, 64, 255))
    img = img.filter(ImageFilter.GaussianBlur(3 * SS))
    d = ImageDraw.Draw(img)
    pin_shape(d, 40, 41, HR + 3.5, 94, (255, 200, 40, 255))
    save(img, "city/map_pin_highlight.png")

def badge(name, size, color, letter_poly=None, ring=(255, 255, 255, 255)):
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    c = size / 2
    d.ellipse(S([1, 1, size - 1, size - 1]), fill=ring)
    d.ellipse(S([3, 3, size - 3, size - 3]), fill=color)
    if letter_poly:
        letter_poly(d, c)
    out = Image.alpha_composite(shadow(img, 1.2, 0.4), img)
    save(out, name)

def metro_m(d, c):
    s = 0.36 * c * 2 / 2
    pts = [(-1, 1), (-1, -1), (0, 0.1), (1, -1), (1, 1)]
    d.line([tuple(S((c + x * s * 1.05, c + y * s))) for x, y in pts], fill=(255, 255, 255, 255), width=int(2.6 * SS), joint="curve")

def anchor(d, c):
    w = (255, 255, 255, 255)
    d.ellipse(S([c - 2.2, c - 7.5, c + 2.2, c - 3.1]), outline=w, width=int(1.4 * SS))
    d.line([tuple(S((c, c - 3))), tuple(S((c, c + 7)))], fill=w, width=int(1.8 * SS))
    d.line([tuple(S((c - 4, c - 1.5))), tuple(S((c + 4, c - 1.5)))], fill=w, width=int(1.6 * SS))
    d.arc(S([c - 7, c - 3, c + 7, c + 8]), 20, 160, fill=w, width=int(1.8 * SS))

def token_disc():
    # Light greyscale disc (tinted per player via modulate): soft top highlight, gentle bottom shade.
    n = 80
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    c = n / 2
    r = 27
    d.ellipse(S([c - r, c - r, c + r, c + r]), fill=(225, 225, 225, 255))
    for i in range(24):
        t = i / 23
        v = int(225 + 30 * t)
        rr = r * (0.95 - t * 0.55)
        d.ellipse(S([c - rr, c - rr - 6 * t, c + rr, c + rr - 6 * t]), fill=(v, v, v, 255))
    mask = canvas(n, n)
    ImageDraw.Draw(mask).ellipse(S([c - r, c - r, c + r, c + r]), fill=(255, 255, 255, 255))
    img.putalpha(mask.split()[3])
    save(img, "token_disc.png")

def token_border():
    n = 80
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    c = n / 2
    d.ellipse(S([c - 31, c - 31, c + 31, c + 31]), fill=(255, 255, 255, 255))
    d.ellipse(S([c - 27, c - 27, c + 27, c + 27]), fill=(0, 0, 0, 0))
    base = canvas(n, n)
    ImageDraw.Draw(base).ellipse(S([c - 31, c - 31, c + 31, c + 31]), fill=(255, 255, 255, 255))
    sh = shadow(base, 3.5, 0.55)
    sh = sh.transform(sh.size, Image.AFFINE, (1, 0, 0, 0, 1, -3 * SS))
    save(Image.alpha_composite(sh, img), "token_border.png")

def last_seen():
    n = 96
    img = canvas(n, n)
    d = ImageDraw.Draw(img)
    c = n / 2
    red = (255, 59, 92, 255)
    d.ellipse(S([c - 40, c - 40, c + 40, c + 40]), outline=red, width=int(5 * SS))
    for a in range(0, 360, 90):
        x = math.cos(math.radians(a))
        y = math.sin(math.radians(a))
        d.line([tuple(S((c + x * 30, c + y * 30))), tuple(S((c + x * 46, c + y * 46)))], fill=red, width=int(5 * SS))
    d.ellipse(S([c - 22, c - 22, c + 22, c + 22]), fill=(255, 59, 92, 70))
    out = Image.alpha_composite(shadow(img, 2, 0.5), img)
    save(out, "last_seen_marker.png")

def rounded(d, box, r, fill):
    d.rounded_rectangle(S(box), radius=r * SS, fill=fill)

def vehicle_base(w, h):
    return canvas(w, h)

def car(name, body, roof_sign=None):
    w, h = 48, 26
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rounded(d, [3, 3, 45, 23], 7, body)
    rounded(d, [27, 6, 36, 20], 3, (40, 52, 70, 255))   # windscreen
    rounded(d, [9, 6, 15, 20], 2, (40, 52, 70, 220))    # rear window
    rounded(d, [16, 7, 26, 19], 2, tuple(min(255, int(c * 1.08)) for c in body[:3]) + (255,))
    if roof_sign:
        rounded(d, [18, 9.5, 24, 16.5], 1.5, roof_sign)
    d.rectangle(S([43, 5, 45, 8]), fill=(255, 250, 200, 255))
    d.rectangle(S([43, 18, 45, 21]), fill=(255, 250, 200, 255))
    out = Image.alpha_composite(shadow(img, 1.5, 0.5), img)
    save(out, "vehicles/" + name)

def bus():
    w, h = 68, 28
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    rounded(d, [3, 3, 65, 25], 5, (46, 184, 122, 255))
    rounded(d, [6, 6, 62, 22], 3, (230, 240, 236, 255))  # roof
    for x in range(10, 56, 9):
        rounded(d, [x, 8.5, x + 5, 19.5], 1.2, (190, 215, 205, 255))  # roof vents
    rounded(d, [57, 6, 63, 22], 2, (40, 52, 70, 255))
    out = Image.alpha_composite(shadow(img, 1.6, 0.5), img)
    save(out, "vehicles/Bus.png")

def train():
    w, h = 92, 26
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    for x0 in (3, 47):
        rounded(d, [x0, 3, x0 + 42, 23], 6, (232, 69, 122, 255))
        rounded(d, [x0 + 4, 7, x0 + 38, 19], 3, (250, 220, 232, 255))
    rounded(d, [44, 9, 48, 17], 1, (120, 40, 70, 255))
    rounded(d, [80, 6, 87, 20], 2, (40, 52, 70, 255))
    out = Image.alpha_composite(shadow(img, 1.6, 0.5), img)
    save(out, "vehicles/Train.png")

def ferry():
    w, h = 64, 32
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    hull = [(4, 6), (46, 4), (60, 16), (46, 28), (4, 26)]
    d.polygon([tuple(S(p)) for p in hull], fill=(250, 250, 252, 255))
    d.line([tuple(S(p)) for p in hull + [hull[0]]], fill=(36, 92, 160, 255), width=int(2 * SS))
    rounded(d, [14, 10, 38, 22], 3, (36, 92, 160, 255))
    rounded(d, [17, 12.5, 35, 19.5], 2, (190, 220, 245, 255))
    out = Image.alpha_composite(shadow(img, 1.6, 0.5), img)
    save(out, "vehicles/Ferry.png")

if __name__ == "__main__":
    station_pin()
    head_part("ring_bus.png", (59, 196, 138, 255), [0, 0, PW, HC[1]])
    head_part("ring_taxi.png", (245, 197, 66, 255), [0, HC[1], PW, PH])
    head_part("ring_underground.png", (232, 69, 122, 255), [0, HC[1] - 5.5, PW, HC[1] + 5.5])
    pin_highlight()
    badge("city/metro_entrance.png", 26, (232, 69, 122, 255), metro_m)
    badge("city/dock.png", 26, (36, 92, 160, 255), anchor)
    token_disc()
    token_border()
    last_seen()
    car("Taxi.png", (245, 197, 66, 255), roof_sign=(40, 40, 40, 255))
    bus()
    train()
    ferry()
    print("board sprites written")
