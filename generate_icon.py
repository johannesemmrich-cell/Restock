#!/usr/bin/env python3
"""Generates the SmartCart app icon at 1024x1024 and writes it to the asset catalog."""

from PIL import Image, ImageDraw
import math, os

SIZE = 1024
OUT = "SmartCart/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Gradient background (blue top-left → deep blue bottom-right)
for y in range(SIZE):
    t = y / SIZE
    r = int(10  + t * (0  - 10))
    g = int(132 + t * (71 - 132))
    b = int(255 + t * (200 - 255))
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

# Soften the gradient with a diagonal overlay
overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
for x in range(SIZE):
    t = x / SIZE
    alpha = int(t * 60)
    od.line([(x, 0), (x, SIZE)], fill=(0, 50, 160, alpha))
img = Image.alpha_composite(img, overlay)
draw = ImageDraw.Draw(img)

# --- Shopping cart path ---
cx, cy = SIZE // 2, SIZE // 2

# Cart body (rounded trapezoid)
body_left   = int(cx - SIZE * 0.28)
body_right  = int(cx + SIZE * 0.28)
body_top    = int(cy - SIZE * 0.10)
body_bottom = int(cy + SIZE * 0.18)
handle_left  = int(cx - SIZE * 0.18)
handle_right = int(cx + SIZE * 0.18)
handle_top   = int(cy - SIZE * 0.28)
lw = int(SIZE * 0.055)  # line width

# Handle arc
draw.arc(
    [handle_left, handle_top, handle_right, body_top + lw * 2],
    start=200, end=340,
    fill=(255, 255, 255, 255),
    width=lw
)

# Cart body rectangle
draw.rounded_rectangle(
    [body_left, body_top, body_right, body_bottom],
    radius=int(SIZE * 0.045),
    fill=(255, 255, 255, 230)
)

# Inner highlight (lighter top portion)
draw.rounded_rectangle(
    [body_left + lw, body_top + lw, body_right - lw, body_top + int(SIZE * 0.08)],
    radius=int(SIZE * 0.03),
    fill=(255, 255, 255, 255)
)

# Wheels
wheel_r = int(SIZE * 0.055)
wheel_y = body_bottom + int(SIZE * 0.04)
for wx in [body_left + int(SIZE * 0.09), body_right - int(SIZE * 0.09)]:
    draw.ellipse(
        [wx - wheel_r, wheel_y - wheel_r, wx + wheel_r, wheel_y + wheel_r],
        fill=(255, 255, 255, 255)
    )
    # Inner circle cutout (give wheel a ring look)
    inner_r = int(wheel_r * 0.45)
    r_int = int(10  * 0.8)
    g_int = int(132 * 0.8)
    b_int = int(255 * 0.8)
    draw.ellipse(
        [wx - inner_r, wheel_y - inner_r, wx + inner_r, wheel_y + inner_r],
        fill=(r_int, g_int, b_int, 255)
    )

# Subtle sparkle star (top-right) — represents "smart"
star_cx = int(cx + SIZE * 0.27)
star_cy = int(cy - SIZE * 0.28)
for angle in range(0, 360, 45):
    rad = math.radians(angle)
    r_outer = int(SIZE * 0.04) if angle % 90 == 0 else int(SIZE * 0.025)
    x = star_cx + int(r_outer * math.cos(rad))
    y = star_cy + int(r_outer * math.sin(rad))
    draw.line(
        [(star_cx, star_cy), (x, y)],
        fill=(255, 255, 255, 200),
        width=int(SIZE * 0.012)
    )

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, "PNG")
print(f"Icon saved to {OUT}")
