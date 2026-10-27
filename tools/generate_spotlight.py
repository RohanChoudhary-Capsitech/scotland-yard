"""
generate_spotlight.py — Generates spotlight radial gradient and edge indicator arrow textures.
"""

import os
import math
from PIL import Image, ImageDraw

def generate_spotlight():
    size = 1024
    radius = size // 2
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = img.load()

    center_x = radius
    center_y = radius

    for y in range(size):
        for x in range(size):
            dx = x - center_x
            dy = y - center_y
            dist = math.sqrt(dx * dx + dy * dy)
            if dist >= radius:
                pixels[x, y] = (255, 255, 255, 0)
            else:
                t = dist / radius  # 0.0 at center, 1.0 at edge
                # Smooth curve: flat bright center up to 0.2, then smooth cosine falloff
                if t < 0.15:
                    alpha = 1.0
                else:
                    norm_t = (t - 0.15) / 0.85
                    alpha = 0.5 * (1.0 + math.cos(math.pi * norm_t))
                    # Add cubic ease for ultra-soft fringe
                    alpha = alpha * alpha
                
                a_byte = int(max(0, min(255, alpha * 255)))
                pixels[x, y] = (255, 255, 255, a_byte)

    out_dir = os.path.join("game", "assets", "sprites", "single", "shared")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "spotlight_gradient.png")
    img.save(out_path)
    print(f"Saved spotlight gradient to {out_path} ({size}x{size})")

def generate_arrow():
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Arrow pointing along +X (to the right)
    # Centered around (32, 32)
    # Draw soft outer glow layers
    glow_color = (245, 197, 66) # #F5C542 gold
    
    # Outer glow
    for offset in range(6, 0, -1):
        alpha = int(25 * (7 - offset))
        pts = [
            (14 - offset, 12 - offset),
            (46 + offset, 32),
            (14 - offset, 52 + offset),
            (24, 32)
        ]
        draw.polygon(pts, fill=(glow_color[0], glow_color[1], glow_color[2], alpha))

    # Core crisp arrow
    pts_core = [
        (16, 14),
        (46, 32),
        (16, 50),
        (26, 32)
    ]
    draw.polygon(pts_core, fill=(255, 240, 180, 255))

    out_dir = os.path.join("game", "assets", "sprites", "single", "shared")
    out_path = os.path.join(out_dir, "gaze_arrow.png")
    img.save(out_path)
    print(f"Saved gaze arrow to {out_path} ({size}x{size})")

if __name__ == "__main__":
    generate_spotlight()
    generate_arrow()
