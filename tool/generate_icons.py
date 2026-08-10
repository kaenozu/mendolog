"""mendolog app icon generator: green rounded card + white log lines + check mark.
Motif: a friction log — stacked lines with a check (record / めんどログ).
All Android densities + adaptive (anydpi-v26) + monochrome.
"""
import os
from PIL import Image, ImageDraw

# app seed color #476b5c, white lines
BG = (71, 107, 92, 255)       # #476b5c
CARD = (255, 255, 255, 255)   # white card
LINE = (71, 107, 92, 255)     # green lines on the card
CHECK = (71, 107, 92, 255)    # green check

OUT = r"C:\Users\neoen\mendolog\android\app\src\main\res"

def draw_legacy(size, path):
    """Full-bleed green background, white rounded card with 3 log lines + check."""
    img = Image.new("RGBA", (size, size), BG)
    d = ImageDraw.Draw(img)
    # card: 66% of size, centered
    card_w = int(size * 0.66)
    card_x0 = (size - card_w) // 2
    card_y0 = int(size * 0.17)
    card_x1, card_y1 = card_x0 + card_w, card_y0 + card_w
    r = int(size * 0.12)
    d.rounded_rectangle([card_x0, card_y0, card_x1, card_y1], radius=r, fill=CARD)
    # 3 log lines
    lw = int(size * 0.09)
    line_h = int(size * 0.07)
    for i in range(3):
        y = card_y0 + int(size * (0.12 + i * 0.13))
        x0 = card_x0 + int(size * 0.11)
        x1 = card_x1 - int(size * 0.11 if i != 0 else 0.24)  # last line shorter
        d.rounded_rectangle([x0, y, x1, y + line_h], radius=line_h // 2, fill=LINE)
    # check mark on the last row center
    cx = card_x0 + card_w // 2
    cy = card_y0 + int(size * (0.12 + 2 * 0.13)) + line_h // 2
    d.line([(cx - int(size*0.10), cy),
            (cx - int(size*0.02), cy + int(size*0.08)),
            (cx + int(size*0.12), cy - int(size*0.08))],
           fill=CHECK, width=max(2, int(size * 0.045)), joint="curve")
    img.save(path)

def draw_foreground(size, path):
    """Adaptive foreground: transparent bg, design inside center 66% safe zone."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # scale: safe zone is 66% of the 108dp canvas
    s = size / 108.0
    card_w = int(66 * s)
    card_x0 = (size - card_w) // 2
    card_y0 = int(18 * s)
    card_x1, card_y1 = card_x0 + card_w, card_y0 + card_w
    r = int(12 * s)
    # white card with border (foreground must be distinguishable on bg color)
    d.rounded_rectangle([card_x0, card_y0, card_x1, card_y1], radius=r, fill=CARD)
    lw = int(10 * s)
    line_h = int(7 * s)
    for i in range(3):
        y = card_y0 + int(13 * s + i * 14 * s)
        x0 = card_x0 + int(12 * s)
        x1 = card_x1 - int(12 * s if i != 0 else 26 * s)
        d.rounded_rectangle([x0, y, x1, y + line_h], radius=line_h // 2, fill=LINE)
    cx = card_x0 + card_w // 2
    cy = card_y0 + int(13 * s + 2 * 14 * s) + line_h // 2
    d.line([(cx - int(11 * s), cy),
            (cx - int(2 * s), cy + int(8 * s)),
            (cx + int(13 * s), cy - int(8 * s))],
           fill=CHECK, width=max(2, int(5 * s)), joint="curve")
    img.save(path)

def main():
    # legacy launcher icons (full-bleed)
    legacy = {
        "mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192,
    }
    for folder, size in legacy.items():
        path = os.path.join(OUT, folder, "ic_launcher.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        draw_legacy(size, path)
        print("wrote", path)
    # adaptive foregrounds (108dp canvas per density)
    fg = {
        "mipmap-mdpi": 108, "mipmap-hdpi": 162, "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324, "mipmap-xxxhdpi": 432,
    }
    for folder, size in fg.items():
        path = os.path.join(OUT, folder, "ic_launcher_foreground.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        draw_foreground(size, path)
        print("wrote", path)
    # adaptive XML (anydpi-v26)
    v26 = os.path.join(OUT, "mipmap-anydpi-v26")
    os.makedirs(v26, exist_ok=True)
    with open(os.path.join(v26, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background"/>\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                '</adaptive-icon>\n')
    print("wrote", os.path.join(v26, "ic_launcher.xml"))
    # background color resource
    vals = os.path.join(OUT, "values")
    os.makedirs(vals, exist_ok=True)
    with open(os.path.join(vals, "ic_launcher_background.xml"), "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<resources>\n'
                '    <color name="ic_launcher_background">#476B5C</color>\n'
                '</resources>\n')
    print("wrote", os.path.join(vals, "ic_launcher_background.xml"))

if __name__ == "__main__":
    main()