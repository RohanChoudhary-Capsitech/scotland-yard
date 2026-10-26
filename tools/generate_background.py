#!/usr/bin/env python3
"""
generate_background.py — Generates CityMap.png for the Scotland Yard board game.
Renders a living city map with green terrain, parks, River Thames, main roads,
and procedural urban side streets denser at the center.
"""

import json
import math
import random
import os
from PIL import Image, ImageDraw, ImageFilter

def generate():
    random.seed(42)

    map_path = os.path.join("game", "assets", "data", "map.json")
    out_path = os.path.join("game", "assets", "sprites", "backgrounds", "CityMap.png")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    with open(map_path, "r", encoding="utf-8") as f:
        map_data = json.load(f)

    margin = 200
    base_w, base_h = 2400, 1800
    img_w, img_h = base_w + margin * 2, base_h + margin * 2 # 2800 x 2200

    print(f"Generating CityMap.png ({img_w}x{img_h})...")

    # 1. Base Green Gradient Canvas (#0F4D24 to #1E7A3A)
    # Using vertical interpolation with subtle organic noise
    base_img = Image.new("RGBA", (img_w, img_h))
    draw = ImageDraw.Draw(base_img)

    c_top = (15, 77, 36)      # #0F4D24
    c_bottom = (30, 122, 58)  # #1E7A3A

    for y in range(img_h):
        t = y / float(img_h)
        # Add slight diagonal slant
        r = int(c_top[0] * (1.0 - t) + c_bottom[0] * t)
        g = int(c_top[1] * (1.0 - t) + c_bottom[1] * t)
        b = int(c_top[2] * (1.0 - t) + c_bottom[2] * t)
        draw.line([(0, y), (img_w, y)], fill=(r, g, b, 255))

    # 2. Add Darker Green City Parks
    # Hyde Park / Regent's Park style parks
    parks_layer = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    pdraw = ImageDraw.Draw(parks_layer)

    parks = [
        # (center_x, center_y, radius_x, radius_y) in board space
        (550 + margin, 550 + margin, 260, 180),   # Northwest Park (Regent's)
        (750 + margin, 800 + margin, 240, 160),   # West Central Park (Hyde)
        (1750 + margin, 500 + margin, 200, 140),  # Northeast Park (Victoria)
        (1600 + margin, 1400 + margin, 280, 170), # South Park (Greenwich / Battersea)
    ]

    for px, py, rx, ry in parks:
        # Rounded organic park blob
        pdraw.ellipse([px - rx, py - ry, px + rx, py + ry], fill=(10, 56, 24, 230))
        # Add slight inner lighter tint
        pdraw.ellipse([px - rx * 0.8, py - ry * 0.8, px + rx * 0.8, py + ry * 0.8], fill=(14, 68, 30, 180))

    base_img.alpha_composite(parks_layer)

    # 3. Procedural City Blocks & Side Streets
    # Sparser at the edges, denser toward center (1200 + margin, 900 + margin)
    streets_layer = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(streets_layer)

    center_x = 1200 + margin
    center_y = 900 + margin
    max_dist = math.hypot(1200, 900)

    # Grid-based block generation with density weighting
    step = 40
    for gx in range(margin // 2, img_w - margin // 2, step):
        for gy in range(margin // 2, img_h - margin // 2, step):
            d_center = math.hypot(gx - center_x, gy - center_y)
            norm_dist = min(1.0, d_center / max_dist)
            # Density probability: 85% at center down to 25% at edges
            prob = 0.85 * (1.0 - norm_dist * 0.7)

            if random.random() < prob:
                # Draw local urban blocks / residential streets
                off_x = random.randint(-6, 6)
                off_y = random.randint(-6, 6)
                block_w = step - random.randint(8, 14)
                block_h = step - random.randint(8, 14)

                bx1 = gx + off_x
                by1 = gy + off_y
                bx2 = bx1 + block_w
                by2 = by1 + block_h

                # Semi-transparent city block fill (subtle building roofs / courtyards)
                block_alpha = int(25 * (1.0 - norm_dist * 0.4))
                sdraw.rectangle([bx1, by1, bx2, by2], fill=(255, 255, 255, block_alpha))

                # Street outline around block (alpha ~25-35%)
                street_alpha = int(60 * (1.0 - norm_dist * 0.3))
                sdraw.rectangle([bx1 - 2, by1 - 2, bx2 + 2, by2 + 2], outline=(255, 255, 255, street_alpha), width=1)

    # 4. Main Roads following Taxi Links from map.json
    stations_dict = {s["id"]: (s["x"] + margin, s["y"] + margin) for s in map_data["stations"]}

    main_roads_layer = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    mdraw = ImageDraw.Draw(main_roads_layer)

    for link in map_data["links"]:
        if link.get("type") == "taxi":
            p1 = stations_dict.get(link["a"])
            p2 = stations_dict.get(link["b"])
            if p1 and p2:
                # Road casing
                mdraw.line([p1, p2], fill=(255, 255, 255, 55), width=5)
                # Road center
                mdraw.line([p1, p2], fill=(235, 245, 235, 80), width=2)

    base_img.alpha_composite(streets_layer)
    base_img.alpha_composite(main_roads_layer)

    # 5. Blue-Green River Band (River Thames)
    river_layer = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(river_layer)

    # Ferry stations in sequence: 71, 19, 16, 34, 98
    # Define river spine points from x=0 to x=img_w
    river_spine = [
        (-50, 1070 + margin),
        (300 + margin, 1075 + margin),
        (628 + margin, 1063 + margin),   # Station 71
        (958 + margin, 1059 + margin),   # Station 19
        (1287 + margin, 1061 + margin),  # Station 16
        (1501 + margin, 1059 + margin),  # Station 34
        (1827 + margin, 1062 + margin),  # Station 98
        (2150 + margin, 1055 + margin),
        (img_w + 50, 1050 + margin),
    ]

    # Subdivide river spine for smooth curves
    smooth_river = []
    for i in range(len(river_spine) - 1):
        pA = river_spine[i]
        pB = river_spine[i + 1]
        for t_step in range(15):
            t = t_step / 15.0
            rx = pA[0] * (1.0 - t) + pB[0] * t
            ry = pA[1] * (1.0 - t) + pB[1] * t
            smooth_river.append((rx, ry))
    smooth_river.append(river_spine[-1])

    # Draw river bank (outer rim)
    river_width = 86
    bank_width = 98

    # Outer bank
    for i in range(len(smooth_river) - 1):
        rdraw.line([smooth_river[i], smooth_river[i + 1]], fill=(22, 75, 88, 220), width=bank_width)

    # Main water body (#1D6B7F)
    for i in range(len(smooth_river) - 1):
        rdraw.line([smooth_river[i], smooth_river[i + 1]], fill=(30, 105, 122, 255), width=river_width)

    # Inner river flow highlight line
    for i in range(len(smooth_river) - 1):
        rdraw.line([smooth_river[i], smooth_river[i + 1]], fill=(45, 135, 155, 140), width=18)

    base_img.alpha_composite(river_layer)

    # 6. Subtle Vignette at extreme border margins
    vignette = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    for i in range(margin):
        alpha = int(120 * (1.0 - i / float(margin)))
        vdraw.rectangle([i, i, img_w - i, img_h - i], outline=(5, 25, 12, alpha), width=1)

    base_img.alpha_composite(vignette)

    # Save final background
    base_img.save(out_path, "PNG", optimize=True)
    print(f"CityMap.png saved successfully to {out_path} ({os.path.getsize(out_path)} bytes)")

if __name__ == "__main__":
    generate()
