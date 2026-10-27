#!/usr/bin/env python3
"""
generate_background.py — Generates CityMap.png (Ground canvas) for Scotland Yard.
Renders an illustrated mobile game style ground:
- Lush grass canvas with subtle organic noise and varied greens
- 3 large darker-green city parks with flower gardens / tree groves
- Small scenic ponds
- River Thames in vibrant blue (#3A8FD9) with lighter sparkling shoreline edges (#72C2F8)
- NO streets or roads drawn into the static image (all roads are now real nodes)
"""

import json
import math
import random
import os
from PIL import Image, ImageDraw, ImageFilter

def generate():
    random.seed(1337)

    map_path = os.path.join("game", "assets", "data", "map.json")
    out_path = os.path.join("game", "assets", "sprites", "backgrounds", "CityMap.png")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    with open(map_path, "r", encoding="utf-8") as f:
        map_data = json.load(f)

    margin = 200
    base_w, base_h = 2400, 1800
    img_w, img_h = base_w + margin * 2, base_h + margin * 2 # 2800 x 2200

    print(f"Generating illustrated Ground canvas ({img_w}x{img_h})...")

    # 1. Base Grass Gradient Canvas (#4A9644 to #58A850)
    base_img = Image.new("RGBA", (img_w, img_h))
    draw = ImageDraw.Draw(base_img)

    c_top = (74, 150, 68)     # #4A9644
    c_bottom = (88, 168, 80)  # #58A850

    for y in range(img_h):
        t = y / float(img_h)
        r = int(c_top[0] * (1.0 - t) + c_bottom[0] * t)
        g = int(c_top[1] * (1.0 - t) + c_bottom[1] * t)
        b = int(c_top[2] * (1.0 - t) + c_bottom[2] * t)
        draw.line([(0, y), (img_w, y)], fill=(r, g, b, 255))

    # 2. Organic Subtle Noise Patches across the grass (meadow variation)
    noise_layer = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    ndraw = ImageDraw.Draw(noise_layer)

    # Scatter soft lighter and darker green meadow spots
    for _ in range(800):
        nx = random.randint(0, img_w)
        ny = random.randint(0, img_h)
        nr = random.randint(40, 120)
        # Alternate subtle lighter vs darker green tint
        if random.random() < 0.5:
            n_color = (60, 130, 55, random.randint(25, 45))  # slightly darker
        else:
            n_color = (105, 185, 95, random.randint(25, 50)) # slightly lighter
        ndraw.ellipse([nx - nr, ny - nr, nx + nr, ny + nr], fill=n_color)

    noise_layer = noise_layer.filter(ImageFilter.GaussianBlur(25.0))
    base_img.alpha_composite(noise_layer)

    # 3. Large Darker Green City Parks
    # Hyde Park / Regent's Park style parks with soft rounded borders
    parks_layer = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(parks_layer)

    parks = [
        # (center_x, center_y, radius_x, radius_y)
        (550 + margin, 520 + margin, 270, 180),   # Regent's Park (Northwest)
        (720 + margin, 850 + margin, 250, 160),   # Hyde Park (West Central)
        (1850 + margin, 520 + margin, 220, 150),  # Victoria Park (Northeast)
        (1650 + margin, 1420 + margin, 290, 180), # Greenwich / Battersea (South)
    ]

    for px, py, rx, ry in parks:
        # Outer park shade
        pdraw.ellipse([px - rx, py - ry, px + rx, py + ry], fill=(35, 95, 40, 220))
        # Inner lawn
        pdraw.ellipse([px - rx * 0.85, py - ry * 0.85, px + rx * 0.85, py + ry * 0.85], fill=(42, 110, 48, 200))
        # Decorative small garden flower patch in center
        pdraw.ellipse([px - 35, py - 25, px + 35, py + 25], fill=(55, 130, 60, 240))

    parks_layer = parks_layer.filter(ImageFilter.GaussianBlur(6.0))
    base_img.alpha_composite(parks_layer)

    # 4. Small Scenic Ponds
    ponds_layer = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    pond_draw = ImageDraw.Draw(ponds_layer)

    ponds = [
        # In Hyde Park
        (720 + margin, 850 + margin, 65, 32, -15),
        # In Regent's Park
        (560 + margin, 530 + margin, 50, 28, 20),
        # In Victoria Park
        (1860 + margin, 510 + margin, 45, 24, 10),
        # South suburb pond
        (1400 + margin, 1550 + margin, 40, 22, -30),
    ]

    for cx, cy, rx, ry, _ang in ponds:
        # Sandy/green bank rim
        pond_draw.ellipse([cx - rx - 5, cy - ry - 5, cx + rx + 5, cy + ry + 5], fill=(70, 140, 65, 200))
        # Pond water (#3A8FD9)
        pond_draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(58, 143, 217, 255))
        # Pond water inner highlight
        pond_draw.ellipse([cx - rx * 0.6, cy - ry * 0.6, cx + rx * 0.6, cy + ry * 0.6], fill=(114, 194, 248, 180))

    ponds_layer = ponds_layer.filter(ImageFilter.GaussianBlur(2.0))
    base_img.alpha_composite(ponds_layer)

    # 5. Blue River (River Thames #3A8FD9 with lighter shoreline edges)
    # Ferry stations in sequence: 71, 19, 16, 34, 98
    stations_dict = {s["id"]: (s["x"] + margin, s["y"] + margin) for s in map_data["stations"]}

    river_layer = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(river_layer)

    # River spine coordinates through ferry stations
    river_spine = [
        (-60, 1070 + margin),
        (300 + margin, 1075 + margin),
        stations_dict.get(71, (628 + margin, 1063 + margin)),
        stations_dict.get(19, (958 + margin, 1059 + margin)),
        stations_dict.get(16, (1287 + margin, 1061 + margin)),
        stations_dict.get(34, (1501 + margin, 1059 + margin)),
        stations_dict.get(98, (1827 + margin, 1062 + margin)),
        (2150 + margin, 1055 + margin),
        (img_w + 60, 1050 + margin),
    ]

    # Subdivide river spine into fine smooth segments
    smooth_river = []
    for i in range(len(river_spine) - 1):
        pA = river_spine[i]
        pB = river_spine[i + 1]
        steps = 20
        for s in range(steps):
            t = s / float(steps)
            rx = pA[0] * (1.0 - t) + pB[0] * t
            ry = pA[1] * (1.0 - t) + pB[1] * t
            smooth_river.append((rx, ry))
    smooth_river.append(river_spine[-1])

    # Widths
    river_width = 88
    shore_width = 104

    # 5a. Lighter shoreline banks (#72C2F8 with soft sand green blend)
    for i in range(len(smooth_river) - 1):
        rdraw.line([smooth_river[i], smooth_river[i + 1]], fill=(114, 194, 248, 220), width=shore_width)

    # 5b. Vibrant Blue Main River body (#3A8FD9)
    for i in range(len(smooth_river) - 1):
        rdraw.line([smooth_river[i], smooth_river[i + 1]], fill=(58, 143, 217, 255), width=river_width)

    # 5c. River flow highlight ribbon
    for i in range(len(smooth_river) - 1):
        rdraw.line([smooth_river[i], smooth_river[i + 1]], fill=(138, 210, 255, 140), width=22)

    river_layer = river_layer.filter(ImageFilter.GaussianBlur(1.5))
    base_img.alpha_composite(river_layer)

    # 6. Subtle soft vignette along extreme canvas boundary
    vignette = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    for i in range(margin // 2):
        alpha = int(70 * (1.0 - i / float(margin // 2)))
        vdraw.rectangle([i, i, img_w - i, img_h - i], outline=(25, 65, 30, alpha), width=1)
    base_img.alpha_composite(vignette)

    # Save final ground image
    base_img.save(out_path, "PNG", optimize=True)
    print(f"CityMap.png saved successfully to {out_path} ({os.path.getsize(out_path)} bytes)")

if __name__ == "__main__":
    generate()
