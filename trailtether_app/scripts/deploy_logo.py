"""
deploy_logo.py  –  Trailtether logo deployment (new transparent-source version)
Run: python scripts/deploy_logo.py

Sources (all pre-sized by user, transparent background):
  trailtether_orange_transparent_512.png  ← master
  trailtether_orange_transparent_192.png
  trailtether_orange_transparent_48.png

Outputs:
  assets/icon/app_icon.png      512×512, orange pin on #0D0D0D dark background
                                 → Android legacy launcher + home-screen hero
  assets/icon/app_icon_fg.png   512×512, transparent  → Android adaptive foreground
  windows/runner/resources/app_icon.ico  multi-size (16/32/48/64/128/256)
                                 → Windows taskbar / EXE icon
"""

import io, struct
from pathlib import Path
from PIL import Image

DOWNLOADS = Path(r"C:\Users\bremn\Downloads")
SRC_512   = DOWNLOADS / "trailtether_orange_transparent_512.png"
ROOT      = Path(__file__).parent.parent   # trailtether_app/
ICON_DIR  = ROOT / "assets" / "icon"
ICON_DIR.mkdir(parents=True, exist_ok=True)

APP_ICON_PATH = ICON_DIR / "app_icon.png"
APP_FG_PATH   = ICON_DIR / "app_icon_fg.png"
ICO_PATH      = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

BG_DARK = (13, 13, 13, 255)   # #0D0D0D — matches app theme

# ── Load master ───────────────────────────────────────────────────────────────
print(f"Loading {SRC_512} …")
src = Image.open(SRC_512).convert("RGBA")
print(f"  Source size: {src.size}")

# ── 1. app_icon.png  (orange pin composited on dark background) ───────────────
bg = Image.new("RGBA", src.size, BG_DARK)
bg.paste(src, (0, 0), src)
app_icon = bg.convert("RGB")          # no alpha needed for this one
app_icon.save(APP_ICON_PATH, "PNG", optimize=True)
print(f"  Saved {APP_ICON_PATH}  ({APP_ICON_PATH.stat().st_size:,} bytes)")

# ── 2. app_icon_fg.png  (transparent — adaptive icon foreground) ──────────────
# Centre the artwork in 110% canvas so there's a little breathing room
canvas_sz  = 512
artwork_sz = int(canvas_sz * 0.85)   # 85% fill — leaves safe zone on all edges
offset     = (canvas_sz - artwork_sz) // 2

artwork = src.resize((artwork_sz, artwork_sz), Image.LANCZOS)
fg = Image.new("RGBA", (canvas_sz, canvas_sz), (0, 0, 0, 0))
fg.paste(artwork, (offset, offset), artwork)
fg.save(APP_FG_PATH, "PNG", optimize=True)
print(f"  Saved {APP_FG_PATH}  ({APP_FG_PATH.stat().st_size:,} bytes)")

# ── 3. Windows ICO (6 sizes, composited on dark background) ──────────────────
ICO_SIZES = [16, 32, 48, 64, 128, 256]

def make_bmp_entry(img: Image.Image) -> bytes:
    """32-bit BGRA BMP (ICO internal format) for sizes <256."""
    img = img.convert("RGBA")
    w, h = img.size
    header = struct.pack("<IiiHHIIiiII",
        40, w, h * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    pixels = bytearray()
    for row in reversed(list(img.getdata())):
        r, g, b, a = row
        pixels += bytes([b, g, r, a])
    row_bytes = ((w + 31) // 32) * 4
    and_mask  = b'\x00' * (row_bytes * h)
    return header + bytes(pixels) + and_mask

def make_png_entry(img: Image.Image) -> bytes:
    """PNG-compressed entry (used for 256px per ICO spec)."""
    buf = io.BytesIO()
    img.convert("RGBA").save(buf, "PNG")
    return buf.getvalue()

entries = []
for size in ICO_SIZES:
    # Composite onto dark bg at each size
    resized_src = src.resize((size, size), Image.LANCZOS)
    bg_s = Image.new("RGBA", (size, size), BG_DARK)
    bg_s.paste(resized_src, (0, 0), resized_src)
    if size == 256:
        entries.append((size, make_png_entry(bg_s)))
    else:
        entries.append((size, make_bmp_entry(bg_s)))

n          = len(entries)
ico_header = struct.pack("<HHH", 0, 1, n)
data_off   = 6 + n * 16
dir_data   = b""
img_data   = b""

for size, data in entries:
    w = h = 0 if size == 256 else size
    dir_data += struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(data), data_off)
    data_off += len(data)
    img_data += data

ICO_PATH.parent.mkdir(parents=True, exist_ok=True)
ICO_PATH.write_bytes(ico_header + dir_data + img_data)
print(f"  Saved {ICO_PATH}  ({ICO_PATH.stat().st_size:,} bytes, {n} sizes)")

print("\nDone! Now run:  dart run flutter_launcher_icons:main")
