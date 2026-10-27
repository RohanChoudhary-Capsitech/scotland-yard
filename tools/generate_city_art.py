#!/usr/bin/env python3
"""
generate_city_art.py — Generates clean illustrated city sprites for Scotland Yard:
- 6 building variants in 3/4 view (light walls, darker side face, coloured roof, soft drop shadow)
- 3 tree variants (round canopy + trunk + soft drop shadow)
- Small dock sprite (wooden pier over water)
- Map-pin sprite (teardrop, white fill, dark outline, tip at bottom)
- Map-pin highlight glow
- Small coloured dots for taxi, bus, underground
- Metro tunnel entrance ("M" emblem / canopy)
- Seamless line dash textures (road dash, metro dash, ferry dots)
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter

CITY_DIR = os.path.join("game", "assets", "sprites", "single", "shared", "city")
SHARED_DIR = os.path.join("game", "assets", "sprites", "single", "shared")

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def draw_soft_shadow(draw, cx, cy, rx, ry, color=(0, 0, 0, 70)):
    """Draws an elliptical soft drop shadow."""
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=color)

# -------------------------------------------------------------
# 1. Building Variants (3/4 View with light front, dark side, colored roof)
# -------------------------------------------------------------
def generate_building_1(path):
    """Suburban cottage / house (red brick roof)"""
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Shadow
    draw_soft_shadow(d, 32, 58, 26, 6, (0, 0, 0, 60))

    # Base coordinates
    # Front face: x in [14, 44], y in [30, 56]
    # Right side face: x in [44, 54], y in [24, 50]
    front_wall = [(14, 30), (44, 30), (44, 56), (14, 56)]
    side_wall = [(44, 30), (54, 24), (54, 50), (44, 56)]
    roof_front = [(10, 30), (29, 14), (48, 30)]
    roof_side = [(29, 14), (48, 30), (58, 24), (39, 8)]

    # Draw walls
    d.polygon(side_wall, fill=(195, 170, 140, 255), outline=(130, 105, 80, 255))
    d.polygon(front_wall, fill=(245, 235, 215, 255), outline=(150, 130, 100, 255))

    # Draw roof
    d.polygon(roof_side, fill=(160, 45, 35, 255), outline=(110, 30, 20, 255))
    d.polygon(roof_front, fill=(215, 65, 50, 255), outline=(130, 35, 25, 255))

    # Windows and door on front face
    d.rectangle([26, 42, 32, 56], fill=(120, 75, 45, 255)) # Door
    d.rectangle([18, 36, 24, 44], fill=(135, 206, 235, 255), outline=(180, 160, 130, 255)) # Window L
    d.rectangle([34, 36, 40, 44], fill=(135, 206, 235, 255), outline=(180, 160, 130, 255)) # Window R

    img.save(path, "PNG")

def generate_building_2(path):
    """Suburban bungalow (blue slate roof)"""
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    draw_soft_shadow(d, 32, 58, 28, 6, (0, 0, 0, 60))

    front_wall = [(12, 34), (44, 34), (44, 56), (12, 56)]
    side_wall = [(44, 34), (54, 28), (54, 50), (44, 56)]
    roof_front = [(8, 34), (28, 18), (48, 34)]
    roof_side = [(28, 18), (48, 34), (58, 28), (38, 12)]

    d.polygon(side_wall, fill=(175, 185, 195, 255), outline=(110, 120, 130, 255))
    d.polygon(front_wall, fill=(235, 240, 245, 255), outline=(140, 150, 160, 255))

    d.polygon(roof_side, fill=(35, 95, 150, 255), outline=(20, 60, 100, 255))
    d.polygon(roof_front, fill=(52, 140, 210, 255), outline=(30, 85, 130, 255))

    # Door and windows
    d.rectangle([25, 43, 31, 56], fill=(90, 100, 110, 255))
    d.rectangle([16, 40, 22, 48], fill=(170, 225, 250, 255), outline=(150, 170, 180, 255))
    d.rectangle([34, 40, 40, 48], fill=(170, 225, 250, 255), outline=(150, 170, 180, 255))

    img.save(path, "PNG")

def generate_building_3(path):
    """Victorian townhouse / brownstone (3 storeys, terracotta roof)"""
    w, h = 64, 76
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    draw_soft_shadow(d, 32, 70, 26, 6, (0, 0, 0, 65))

    front_wall = [(14, 24), (44, 24), (44, 68), (14, 68)]
    side_wall = [(44, 24), (54, 18), (54, 62), (44, 68)]
    roof = [(14, 24), (20, 10), (50, 10), (44, 24)]
    roof_side = [(50, 10), (56, 12), (54, 18), (44, 24)]

    d.polygon(side_wall, fill=(160, 85, 65, 255), outline=(110, 50, 40, 255))
    d.polygon(front_wall, fill=(225, 135, 105, 255), outline=(140, 70, 50, 255))
    d.polygon(roof, fill=(190, 80, 55, 255), outline=(120, 45, 30, 255))
    d.polygon(roof_side, fill=(140, 55, 35, 255), outline=(90, 30, 20, 255))

    # 3 Storeys of windows
    for floor_y in [28, 42, 56]:
        d.rectangle([18, floor_y, 25, floor_y + 8], fill=(200, 235, 255, 255), outline=(100, 50, 40, 255))
        if floor_y != 56:
            d.rectangle([32, floor_y, 39, floor_y + 8], fill=(200, 235, 255, 255), outline=(100, 50, 40, 255))
        else:
            d.rectangle([32, 54, 40, 68], fill=(60, 40, 30, 255)) # Brownstone front door

    img.save(path, "PNG")

def generate_building_4(path):
    """Commercial office building (green copper roof, awning)"""
    w, h = 64, 84
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    draw_soft_shadow(d, 32, 78, 28, 6, (0, 0, 0, 65))

    front_wall = [(12, 22), (44, 22), (44, 76), (12, 76)]
    side_wall = [(44, 22), (56, 14), (56, 68), (44, 76)]
    roof = [(12, 22), (18, 10), (50, 10), (44, 22)]
    roof_side = [(50, 10), (58, 8), (56, 14), (44, 22)]

    d.polygon(side_wall, fill=(180, 150, 70, 255), outline=(120, 95, 40, 255))
    d.polygon(front_wall, fill=(240, 210, 120, 255), outline=(150, 125, 60, 255))
    d.polygon(roof, fill=(45, 165, 95, 255), outline=(25, 105, 55, 255)) # Green copper
    d.polygon(roof_side, fill=(30, 115, 65, 255), outline=(15, 75, 40, 255))

    # Grid of office windows
    for y in [26, 38, 50]:
        for x in [16, 26, 36]:
            d.rectangle([x, y, x + 6, y + 8], fill=(185, 225, 245, 255), outline=(130, 110, 50, 255))

    # Ground floor awning
    awning = [(10, 64), (46, 64), (46, 68), (10, 68)]
    d.rectangle([10, 64, 46, 68], fill=(230, 125, 35, 255))
    # Entrance
    d.rectangle([24, 68, 34, 76], fill=(60, 70, 80, 255))

    img.save(path, "PNG")

def generate_building_5(path):
    """Downtown glass & steel high-rise (cool cyan-grey)"""
    w, h = 64, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    draw_soft_shadow(d, 32, 90, 26, 6, (0, 0, 0, 70))

    front_wall = [(14, 18), (44, 18), (44, 88), (14, 88)]
    side_wall = [(44, 18), (54, 12), (54, 82), (44, 88)]
    roof = [(14, 18), (18, 8), (48, 8), (44, 18)]
    roof_side = [(48, 8), (56, 6), (54, 12), (44, 18)]

    d.polygon(side_wall, fill=(105, 125, 140, 255), outline=(65, 80, 95, 255))
    d.polygon(front_wall, fill=(195, 215, 230, 255), outline=(110, 130, 145, 255))
    d.polygon(roof, fill=(75, 95, 110, 255), outline=(45, 60, 75, 255))
    d.polygon(roof_side, fill=(55, 70, 85, 255), outline=(35, 45, 55, 255))

    # Rooftop antenna
    d.line([(32, 8), (32, 2)], fill=(200, 210, 220, 255), width=2)

    # Reflective window bands
    for y in range(22, 82, 10):
        d.rectangle([17, y, 41, y + 6], fill=(130, 190, 225, 255), outline=(90, 140, 175, 255))

    # Lobby glass
    d.rectangle([18, 82, 40, 88], fill=(90, 140, 170, 255))

    img.save(path, "PNG")

def generate_building_6(path):
    """Grand neoclassical civic hall / museum (dome + columns)"""
    w, h = 80, 88
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    draw_soft_shadow(d, 40, 82, 34, 7, (0, 0, 0, 75))

    front_wall = [(16, 32), (56, 32), (56, 80), (16, 80)]
    side_wall = [(56, 32), (68, 24), (68, 72), (56, 80)]

    d.polygon(side_wall, fill=(175, 180, 185, 255), outline=(120, 125, 130, 255))
    d.polygon(front_wall, fill=(240, 242, 245, 255), outline=(160, 165, 170, 255))

    # Classical Pediment (Triangle)
    pediment = [(14, 32), (36, 18), (58, 32)]
    pediment_side = [(36, 18), (58, 32), (68, 24), (46, 12)]
    d.polygon(pediment_side, fill=(160, 165, 170, 255), outline=(110, 115, 120, 255))
    d.polygon(pediment, fill=(245, 248, 250, 255), outline=(140, 145, 150, 255))

    # Central Copper Dome
    d.ellipse([26, 4, 46, 24], fill=(35, 155, 130, 255), outline=(20, 100, 85, 255))

    # Marble Columns on front
    for col_x in [22, 30, 38, 46]:
        d.line([(col_x, 34), (col_x, 74)], fill=(205, 210, 215, 255), width=3)

    # Grand entrance
    d.rectangle([32, 60, 42, 80], fill=(70, 45, 30, 255))

    img.save(path, "PNG")

# -------------------------------------------------------------
# 2. Tree Variants (Round Canopy + Trunk + Soft Drop Shadow)
# -------------------------------------------------------------
def generate_tree_1(path):
    """Lush round oak tree"""
    w, h = 44, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Shadow
    draw_soft_shadow(d, 22, 44, 14, 4, (0, 0, 0, 60))

    # Trunk
    d.rectangle([19, 30, 25, 44], fill=(115, 75, 45, 255))

    # Canopy layers (bottom to top for depth)
    d.ellipse([6, 12, 38, 38], fill=(30, 125, 65, 255))  # Deep base green
    d.ellipse([8, 8, 36, 32], fill=(45, 175, 85, 255))   # Mid green
    d.ellipse([12, 6, 30, 22], fill=(80, 210, 115, 255)) # Top highlight green

    img.save(path, "PNG")

def generate_tree_2(path):
    """Conifer / pine tree (layered tiers)"""
    w, h = 40, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    draw_soft_shadow(d, 20, 44, 13, 4, (0, 0, 0, 60))

    # Trunk
    d.rectangle([18, 36, 22, 44], fill=(100, 65, 40, 255))

    # 3 Pine tiers
    # Bottom tier
    d.polygon([(6, 36), (34, 36), (20, 22)], fill=(25, 95, 65, 255))
    # Middle tier
    d.polygon([(9, 26), (31, 26), (20, 14)], fill=(40, 130, 85, 255))
    # Top tier
    d.polygon([(12, 16), (28, 16), (20, 4)], fill=(65, 175, 110, 255))

    img.save(path, "PNG")

def generate_tree_3(path):
    """Golden-green willow / park tree"""
    w, h = 44, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    draw_soft_shadow(d, 22, 44, 15, 4, (0, 0, 0, 60))

    d.rectangle([19, 32, 25, 44], fill=(125, 80, 45, 255))

    d.ellipse([6, 14, 38, 38], fill=(40, 140, 70, 255))
    d.ellipse([10, 10, 36, 32], fill=(85, 185, 100, 255))
    d.ellipse([14, 8, 30, 22], fill=(155, 215, 110, 255)) # Golden highlight

    img.save(path, "PNG")

# -------------------------------------------------------------
# 3. Small Dock Sprite (Wooden Pier)
# -------------------------------------------------------------
def generate_dock(path):
    """Small wooden dock / pier"""
    w, h = 44, 36
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Water reflection shadow
    draw_soft_shadow(d, 22, 28, 18, 6, (15, 55, 75, 100))

    # Wooden pier deck (horizontal planks)
    # Main platform
    d.rectangle([8, 8, 36, 26], fill=(165, 120, 80, 255), outline=(100, 65, 40, 255))

    # Planks lines
    for px in range(12, 36, 4):
        d.line([(px, 8), (px, 26)], fill=(125, 85, 55, 255), width=1)

    # Mooring posts / bollards at 4 corners
    for bx, by in [(9, 9), (34, 9), (9, 24), (34, 24)]:
        d.ellipse([bx - 3, by - 4, bx + 3, by + 3], fill=(80, 50, 30, 255), outline=(50, 30, 15, 255))
        d.ellipse([bx - 2, by - 3, bx + 2, by], fill=(130, 90, 60, 255)) # Highlight top

    img.save(path, "PNG")

# -------------------------------------------------------------
# 4. Map Pin & Highlight
# -------------------------------------------------------------
def generate_map_pin(path):
    """
    Illustrated map pin:
    Teardrop with needle point anchored at bottom (center-x, bottom-y).
    White fill, clean dark outline, crisp room for station number label.
    """
    w, h = 36, 48
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Drop shadow at tip
    draw_soft_shadow(d, 18, 46, 8, 2.5, (0, 0, 0, 80))

    # Head center: (18, 16), radius: 14
    # Tip point: (18, 44)
    # Outer dark border
    pin_pts = [
        (18, 45),       # Tip
        (6, 23),        # Tangent Left
        (4, 16),        # Outer Left
        (6, 8),         # Upper Left
        (12, 3),        # Top Left
        (18, 2),        # Top Apex
        (24, 3),        # Top Right
        (30, 8),        # Upper Right
        (32, 16),       # Outer Right
        (30, 23),       # Tangent Right
    ]

    # Draw dark casing (outline)
    d.polygon(pin_pts, fill=(35, 45, 55, 255))

    # Inner crisp white fill
    inner_pts = [
        (18, 42),
        (8, 22),
        (6, 16),
        (8, 9),
        (13, 5),
        (18, 4),
        (23, 5),
        (28, 9),
        (30, 16),
        (28, 22),
    ]
    d.polygon(inner_pts, fill=(255, 255, 255, 255))

    # Subtle inner circular shading ring to give mobile-game pop
    d.ellipse([7, 5, 29, 27], outline=(220, 225, 230, 255), width=1)

    img.save(path, "PNG")

def generate_map_pin_highlight(path):
    """Golden pulsing outer glow for the map pin"""
    w, h = 48, 60
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Glow teardrop centered
    glow_pts = [
        (24, 56),
        (10, 30),
        (7, 21),
        (10, 11),
        (17, 5),
        (24, 3),
        (31, 5),
        (38, 11),
        (41, 21),
        (38, 30),
    ]
    # Warm golden halo
    d.polygon(glow_pts, fill=(255, 215, 0, 180))

    # Blur for soft glow
    img = img.filter(ImageFilter.GaussianBlur(3.0))
    img.save(path, "PNG")

# -------------------------------------------------------------
# 5. Coloured Transit Indicator Dots
# -------------------------------------------------------------
def generate_transit_dot(path, color_rgb):
    """Small crisp coloured dot for transit badges"""
    w, h = 12, 12
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Dark rim
    d.ellipse([0, 0, 11, 11], fill=(40, 50, 60, 255))
    # Core color
    d.ellipse([1, 1, 10, 10], fill=(*color_rgb, 255))
    # Little top specular highlight
    d.ellipse([3, 2, 6, 4], fill=(255, 255, 255, 180))

    img.save(path, "PNG")

# -------------------------------------------------------------
# 6. Metro Entrance Sprite ("M" roundel / canopy)
# -------------------------------------------------------------
def generate_metro_entrance(path):
    """Subway / Underground entrance token with London-style badge"""
    w, h = 24, 24
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Shadow
    draw_soft_shadow(d, 12, 22, 9, 2.5, (0, 0, 0, 70))

    # Outer blue disc
    d.ellipse([2, 2, 21, 21], fill=(232, 69, 122, 255), outline=(40, 50, 60, 255))

    # Inner white circle
    d.ellipse([5, 5, 18, 18], fill=(255, 255, 255, 255))

    # Bold Pink "M" logo
    # Left leg
    d.line([(8, 15), (8, 9)], fill=(232, 69, 122, 255), width=2)
    # Diagonals
    d.line([(8, 9), (12, 13)], fill=(232, 69, 122, 255), width=2)
    d.line([(12, 13), (15, 9)], fill=(232, 69, 122, 255), width=2)
    # Right leg
    d.line([(15, 9), (15, 15)], fill=(232, 69, 122, 255), width=2)

    img.save(path, "PNG")

# -------------------------------------------------------------
# 7. Road & Line Dash Textures
# -------------------------------------------------------------
def generate_line_dash(path, w, h, fill_color, dash_w):
    """Generates a repeating dash tile for Line2D textures."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    start_x = (w - dash_w) // 2
    d.rectangle([start_x, 0, start_x + dash_w - 1, h - 1], fill=fill_color)
    img.save(path, "PNG")

def generate_line_dots(path, w, h, fill_color, radius):
    """Generates a repeating dot tile for dotted lines."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx, cy = w // 2, h // 2
    d.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=fill_color)
    img.save(path, "PNG")

def main():
    ensure_dir(CITY_DIR)
    ensure_dir(SHARED_DIR)

    print("Generating illustrated city sprites...")

    # Buildings 1..6
    generate_building_1(os.path.join(CITY_DIR, "building_1.png"))
    generate_building_2(os.path.join(CITY_DIR, "building_2.png"))
    generate_building_3(os.path.join(CITY_DIR, "building_3.png"))
    generate_building_4(os.path.join(CITY_DIR, "building_4.png"))
    generate_building_5(os.path.join(CITY_DIR, "building_5.png"))
    generate_building_6(os.path.join(CITY_DIR, "building_6.png"))

    # Trees 1..3
    generate_tree_1(os.path.join(CITY_DIR, "tree_1.png"))
    generate_tree_2(os.path.join(CITY_DIR, "tree_2.png"))
    generate_tree_3(os.path.join(CITY_DIR, "tree_3.png"))

    # Dock
    generate_dock(os.path.join(CITY_DIR, "dock.png"))

    # Map Pin & Highlight
    generate_map_pin(os.path.join(CITY_DIR, "map_pin.png"))
    generate_map_pin_highlight(os.path.join(CITY_DIR, "map_pin_highlight.png"))

    # Transit dots (12x12)
    generate_transit_dot(os.path.join(CITY_DIR, "dot_taxi.png"), (245, 197, 66))        # #F5C542
    generate_transit_dot(os.path.join(CITY_DIR, "dot_bus.png"), (59, 196, 138))         # #3BC48A
    generate_transit_dot(os.path.join(CITY_DIR, "dot_underground.png"), (232, 69, 122)) # #E8457A

    # Metro Entrance
    generate_metro_entrance(os.path.join(CITY_DIR, "metro_entrance.png"))

    # Line textures
    # Road dash (thin white dashed centre line): 20px wide tile, 10px dash, 2px high
    generate_line_dash(os.path.join(SHARED_DIR, "road_dash.png"), 20, 4, (255, 255, 255, 230), 10)
    # Metro dash (thin pink dash): 24px wide tile, 14px dash, 4px high
    generate_line_dash(os.path.join(SHARED_DIR, "metro_dash.png"), 24, 4, (232, 69, 122, 230), 14)
    # Ferry dots: 18px wide tile, 4px radius circle
    generate_line_dots(os.path.join(SHARED_DIR, "ferry_dash.png"), 18, 6, (255, 255, 255, 240), 3)

    print("All city sprites generated successfully in:", CITY_DIR)

if __name__ == "__main__":
    main()
