#!/usr/bin/env python3
"""
generate_visual_assets.py — 程序化生成"二次元/anime 风格"占位美术资产。

策略：
  - 由于免费 CC0 anime 美术资源很难自动化精准下载，本脚本用 PIL
    生成"风格暗示足够"的占位图：柔和粉彩渐变、轮廓塔形、
    星点/云朵粒子、椭圆头像 + 标志性发型剪影 + 大眼。
  - 所有图我们自行生成 → 自动 CC0 / public domain。
  - 输出到 assets/visual/{backgrounds,portraits,ui,particles}/。

不会替代真实美术，但远胜纯 ColorRect 占位，并保留切换为真美术的接口。
"""

import os
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "visual"
BG_DIR = OUT / "backgrounds"
P_DIR = OUT / "portraits"
UI_DIR = OUT / "ui"
PART_DIR = OUT / "particles"

BG_W, BG_H = 1280, 720
P_W, P_H = 256, 384


def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgradient(w, h, top, bot):
    """Vertical pastel gradient base."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = lerp_color(top, bot, t) + (255,)
        for x in range(w):
            px[x, y] = c
    return img


def add_radial_glow(img, center, radius, color, alpha=120):
    """Soft radial bloom — simulates sun/moon/magic glow."""
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    cx, cy = center
    steps = 18
    for i in range(steps):
        r = int(radius * (1.0 - i / steps))
        a = int(alpha * (i / steps) * (i / steps))
        od.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    overlay = overlay.filter(ImageFilter.GaussianBlur(8))
    return Image.alpha_composite(img, overlay)


def add_stars(img, count=120, color=(255, 255, 255), alpha_max=200, seed=1):
    rng = random.Random(seed)
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for _ in range(count):
        x = rng.randint(0, w - 1)
        y = rng.randint(0, int(h * 0.65))
        s = rng.choice([1, 1, 1, 2, 2, 3])
        a = rng.randint(60, alpha_max)
        od.ellipse([x - s, y - s, x + s, y + s], fill=color + (a,))
    return Image.alpha_composite(img, overlay)


def add_clouds(img, count=8, color=(255, 240, 230), alpha=130, seed=7):
    rng = random.Random(seed)
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for _ in range(count):
        cx = rng.randint(-50, w + 50)
        cy = rng.randint(int(h * 0.05), int(h * 0.55))
        size = rng.randint(80, 220)
        # Cluster 4-6 ellipses
        for _ in range(rng.randint(4, 7)):
            ox = rng.randint(-size // 2, size // 2)
            oy = rng.randint(-size // 5, size // 5)
            sx = rng.randint(size // 2, size)
            sy = rng.randint(size // 4, size // 2)
            od.ellipse([cx + ox - sx // 2, cy + oy - sy // 2,
                        cx + ox + sx // 2, cy + oy + sy // 2],
                       fill=color + (alpha,))
    overlay = overlay.filter(ImageFilter.GaussianBlur(6))
    return Image.alpha_composite(img, overlay)


def silhouette_tower(img, base_color=(40, 30, 70), alpha=235,
                     base_y_ratio=0.95, top_y_ratio=0.18, roof_y_ratio=0.05,
                     bw_base=240, bw_top=90):
    """Magical tower silhouette in anime fantasy style — narrow tapered
    body with stacked tiers and a pointed roof.

    base_y_ratio / top_y_ratio 控制塔的纵向区间（0=顶 1=底）。
    城市场景把塔限制在上半部分（base_y_ratio≈0.55），给底部城镇建筑留空间。
    """
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    cx = w // 2
    base_y = int(h * base_y_ratio)
    top_y = int(h * top_y_ratio)
    # Trapezoid body
    od.polygon([(cx - bw_base // 2, base_y), (cx + bw_base // 2, base_y),
                (cx + bw_top // 2, top_y), (cx - bw_top // 2, top_y)],
               fill=base_color + (alpha,))
    # Tier discs — proportional to (top_y_ratio, base_y_ratio) 区间
    span = base_y_ratio - top_y_ratio
    tier_ratios = [0.78, 0.62, 0.46, 0.32]
    tier_widths = [int(bw_base * f) for f in (0.91, 0.79, 0.66, 0.54)]
    for raw_r, ww in zip(tier_ratios, tier_widths):
        # raw_r 原 0.18→0.95 区间，重映到 (top_y_ratio, base_y_ratio)
        actual = top_y_ratio + (raw_r - 0.18) / 0.77 * span
        ty = int(h * actual)
        od.rectangle([cx - ww // 2, ty - 16, cx + ww // 2, ty + 8],
                     fill=lerp_color(base_color, (60, 50, 110), 0.3) + (alpha,))
    # Pointed roof
    od.polygon([(cx - bw_top // 2, top_y), (cx + bw_top // 2, top_y),
                (cx, int(h * roof_y_ratio))],
               fill=lerp_color(base_color, (90, 60, 130), 0.4) + (alpha,))
    # Windows (warm yellow glow dots) — 一样 remap
    for raw_r in [0.74, 0.58, 0.42]:
        actual = top_y_ratio + (raw_r - 0.18) / 0.77 * span
        ty = int(h * actual)
        for dx in (-30, 0, 30):
            od.rectangle([cx + dx - 5, ty - 30, cx + dx + 5, ty - 18],
                         fill=(255, 220, 130, 230))
    return Image.alpha_composite(img, overlay)


def ground_silhouette(img, color=(20, 15, 35), height_ratio=0.18, alpha=235):
    w, h = img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    base = int(h * (1.0 - height_ratio))
    pts = [(0, h), (w, h), (w, base + 20)]
    # Hill curve
    for x in range(w, -1, -16):
        y = base - int(20 * math.sin(x / 180.0)) - int(40 * math.sin(x / 80.0 + 1.5))
        pts.append((x, y))
    od.polygon(pts, fill=color + (alpha,))
    return Image.alpha_composite(img, overlay)


def vignette(img, strength=0.5):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    steps = 40
    step_px = max(1, min(w, h) // (steps * 2))
    for r in range(steps):
        x0 = r * step_px
        y0 = r * step_px
        x1 = w - r * step_px
        y1 = h - r * step_px
        if x1 <= x0 or y1 <= y0:
            break
        a = int(255 * strength * (r / steps) ** 2)
        md.rectangle([x0, y0, x1, y1], outline=a)
    mask = mask.filter(ImageFilter.GaussianBlur(min(40, max(8, min(w, h) // 16))))
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    overlay.putalpha(mask)
    return Image.alpha_composite(img, overlay)


# ─── Background presets ──────────────────────────────────────────────

def bg_main_menu():
    """Magical tower in clouds at sunset — dreamy hopeful."""
    img = vgradient(BG_W, BG_H, (255, 187, 168), (110, 90, 175))
    img = add_radial_glow(img, (BG_W * 0.7, BG_H * 0.35), 240, (255, 220, 170), alpha=160)
    img = add_clouds(img, count=10, color=(255, 230, 220), alpha=140, seed=3)
    img = add_stars(img, count=80, color=(255, 250, 230), alpha_max=180, seed=11)
    img = silhouette_tower(img, base_color=(48, 35, 80), alpha=230)
    img = vignette(img, strength=0.35)
    return img


def bg_city():
    """Warm cozy plaza at base of tower — dusk pastels.

    塔限制在画面上半部（base_y_ratio=0.55），给城镇建筑留下半部空间。
    """
    img = vgradient(BG_W, BG_H, (255, 210, 180), (90, 70, 140))
    img = add_radial_glow(img, (BG_W * 0.5, BG_H * 0.25), 200, (255, 230, 180), alpha=150)
    img = add_clouds(img, count=6, color=(255, 240, 220), alpha=120, seed=21)
    # Small distant tower in upper half only — let 5 buildings sit at ground in lower half.
    img = silhouette_tower(img, base_color=(50, 38, 85), alpha=180,
                            base_y_ratio=0.55, top_y_ratio=0.10, roof_y_ratio=0.03,
                            bw_base=140, bw_top=60)
    # Ground (city silhouette implied) at bottom — fills the buildings' row backdrop
    img = ground_silhouette(img, color=(35, 25, 60), height_ratio=0.16, alpha=240)
    img = vignette(img, strength=0.30)
    return img


def bg_floor_0F():
    """Ancient hall with letters floating — warm amber."""
    img = vgradient(BG_W, BG_H, (255, 220, 150), (110, 60, 70))
    img = add_radial_glow(img, (BG_W * 0.5, BG_H * 0.45), 280, (255, 240, 190), alpha=180)
    # "Letter" particles (small bright squares)
    rng = random.Random(31)
    overlay = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for _ in range(60):
        x = rng.randint(40, BG_W - 40)
        y = rng.randint(40, int(BG_H * 0.85))
        s = rng.randint(6, 14)
        a = rng.randint(120, 220)
        col = rng.choice([(255, 240, 200), (255, 220, 170), (250, 230, 200)])
        od.rectangle([x - s // 2, y - s // 2, x + s // 2, y + s // 2], fill=col + (a,))
    img = Image.alpha_composite(img, overlay.filter(ImageFilter.GaussianBlur(1)))
    img = ground_silhouette(img, color=(50, 25, 30), height_ratio=0.10, alpha=230)
    img = vignette(img, strength=0.40)
    return img


def bg_floor_1F():
    """Magical library with floating books — purple/teal."""
    img = vgradient(BG_W, BG_H, (170, 140, 220), (40, 30, 90))
    img = add_radial_glow(img, (BG_W * 0.5, BG_H * 0.30), 260, (200, 220, 255), alpha=170)
    img = add_stars(img, count=140, color=(220, 230, 255), alpha_max=210, seed=41)
    # "Book" rectangles drifting
    rng = random.Random(43)
    overlay = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    book_palette = [(180, 140, 90), (140, 80, 60), (90, 130, 180), (160, 100, 140)]
    for _ in range(28):
        x = rng.randint(60, BG_W - 60)
        y = rng.randint(60, int(BG_H * 0.80))
        bw = rng.randint(22, 38)
        bh = rng.randint(28, 46)
        col = rng.choice(book_palette)
        od.rectangle([x, y, x + bw, y + bh], fill=col + (220,))
        od.rectangle([x + 3, y + 4, x + bw - 3, y + 6], fill=(245, 230, 200, 200))
    img = Image.alpha_composite(img, overlay.filter(ImageFilter.GaussianBlur(0.8)))
    img = ground_silhouette(img, color=(20, 15, 50), height_ratio=0.12, alpha=235)
    img = vignette(img, strength=0.45)
    return img


def bg_floor_2F():
    """Family-themed warm interior — soft pink/cream."""
    img = vgradient(BG_W, BG_H, (255, 200, 200), (120, 90, 130))
    img = add_radial_glow(img, (BG_W * 0.5, BG_H * 0.40), 220, (255, 220, 200), alpha=160)
    img = add_clouds(img, count=5, color=(255, 235, 230), alpha=110, seed=51)
    # Heart particles
    rng = random.Random(53)
    overlay = Image.new("RGBA", (BG_W, BG_H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for _ in range(40):
        x = rng.randint(40, BG_W - 40)
        y = rng.randint(40, int(BG_H * 0.80))
        s = rng.randint(6, 12)
        a = rng.randint(140, 210)
        # Heart approx: two circles + diamond
        od.ellipse([x - s, y - s, x, y], fill=(255, 150, 180, a))
        od.ellipse([x, y - s, x + s, y], fill=(255, 150, 180, a))
        od.polygon([(x - s, y - s // 2), (x + s, y - s // 2), (x, y + s)],
                   fill=(255, 150, 180, a))
    img = Image.alpha_composite(img, overlay.filter(ImageFilter.GaussianBlur(0.8)))
    img = ground_silhouette(img, color=(60, 30, 50), height_ratio=0.14, alpha=235)
    img = vignette(img, strength=0.35)
    return img


def bg_boss_battle():
    """Dim dramatic boss arena — deep crimson/violet."""
    img = vgradient(BG_W, BG_H, (90, 30, 60), (15, 10, 35))
    img = add_radial_glow(img, (BG_W * 0.5, BG_H * 0.30), 320, (255, 90, 120), alpha=160)
    img = add_stars(img, count=60, color=(255, 200, 220), alpha_max=180, seed=71)
    img = silhouette_tower(img, base_color=(20, 10, 30), alpha=240)
    img = vignette(img, strength=0.55)
    return img


def bg_settlement():
    """Ethereal magical settlement — pale teal/gold."""
    img = vgradient(BG_W, BG_H, (200, 240, 230), (70, 110, 150))
    img = add_radial_glow(img, (BG_W * 0.5, BG_H * 0.25), 260, (255, 240, 200), alpha=180)
    img = add_clouds(img, count=8, color=(255, 250, 240), alpha=140, seed=81)
    img = add_stars(img, count=180, color=(255, 250, 240), alpha_max=200, seed=83)
    img = vignette(img, strength=0.25)
    return img


# ─── Portrait generator ─────────────────────────────────────────────

def _draw_face(od, cx, cy, fw, fh, skin):
    """Oval face."""
    od.ellipse([cx - fw // 2, cy - fh // 2, cx + fw // 2, cy + fh // 2],
               fill=skin + (255,))


def _draw_eyes(od, cx, cy, fw, eye_color=(40, 50, 110)):
    """Two large anime eyes."""
    eye_y = cy + 6
    eye_w = fw // 5
    eye_h = int(fw // 3.5)
    for sgn in (-1, 1):
        ex = cx + sgn * (fw // 5)
        # Eye white
        od.ellipse([ex - eye_w // 2, eye_y - eye_h // 2,
                    ex + eye_w // 2, eye_y + eye_h // 2],
                   fill=(255, 255, 255, 255))
        # Iris
        ir = int(eye_w * 0.85)
        od.ellipse([ex - ir // 2, eye_y - ir // 2 + 2,
                    ex + ir // 2, eye_y + ir // 2 + 2],
                   fill=eye_color + (255,))
        # Pupil
        pr = int(ir * 0.45)
        od.ellipse([ex - pr // 2, eye_y - pr // 2 + 2,
                    ex + pr // 2, eye_y + pr // 2 + 2],
                   fill=(20, 20, 30, 255))
        # Highlight
        hr = max(2, int(ir * 0.22))
        od.ellipse([ex - hr // 2 - 4, eye_y - hr // 2 - 4,
                    ex + hr // 2 - 4, eye_y + hr // 2 - 4],
                   fill=(255, 255, 255, 255))


def _draw_mouth(od, cx, cy, fw, color=(180, 70, 100), smile=True):
    mw = fw // 6
    my = cy + int(fw * 0.45)
    if smile:
        od.arc([cx - mw, my - 4, cx + mw, my + 8], 0, 180, fill=color + (255,), width=2)
    else:
        od.line([cx - mw // 2, my, cx + mw // 2, my], fill=color + (255,), width=2)


def _draw_blush(od, cx, cy, fw, color=(255, 170, 180)):
    bw = fw // 6
    by = cy + int(fw * 0.30)
    for sgn in (-1, 1):
        bx = cx + sgn * int(fw * 0.42)
        od.ellipse([bx - bw // 2, by - bw // 4, bx + bw // 2, by + bw // 4],
                   fill=color + (140,))


def _draw_hair(od, cx, cy, fw, fh, hair_color, style="bangs"):
    """Anime hair silhouette covering top of head."""
    top = cy - fh // 2
    if style == "bangs":
        # Curtain bangs + side locks
        od.pieslice([cx - fw // 2 - 6, top - 18, cx + fw // 2 + 6, top + fh - 30],
                    180, 360, fill=hair_color + (255,))
        # Bang fringe
        od.polygon([(cx - fw // 2 + 4, top + 8),
                    (cx + fw // 2 - 4, top + 8),
                    (cx + 30, top + 50),
                    (cx, top + 30),
                    (cx - 30, top + 50)],
                   fill=hair_color + (255,))
        # Side locks
        od.polygon([(cx - fw // 2 - 4, top + 20),
                    (cx - fw // 2 + 18, top + 20),
                    (cx - fw // 2 + 8, top + fh // 2 + 30)],
                   fill=hair_color + (255,))
        od.polygon([(cx + fw // 2 + 4, top + 20),
                    (cx + fw // 2 - 18, top + 20),
                    (cx + fw // 2 - 8, top + fh // 2 + 30)],
                   fill=hair_color + (255,))
    elif style == "long":
        # Long flowing
        od.pieslice([cx - fw // 2 - 10, top - 22, cx + fw // 2 + 10, top + fh - 24],
                    180, 360, fill=hair_color + (255,))
        od.polygon([(cx - fw // 2 - 10, top + 30),
                    (cx - fw // 2 + 10, top + 30),
                    (cx - fw // 2 - 6, top + fh + 60),
                    (cx - fw // 2 - 26, top + fh + 80)],
                   fill=hair_color + (255,))
        od.polygon([(cx + fw // 2 + 10, top + 30),
                    (cx + fw // 2 - 10, top + 30),
                    (cx + fw // 2 + 6, top + fh + 60),
                    (cx + fw // 2 + 26, top + fh + 80)],
                   fill=hair_color + (255,))
        od.polygon([(cx - fw // 2 + 8, top + 20),
                    (cx + fw // 2 - 8, top + 20),
                    (cx + 20, top + 40),
                    (cx, top + 28),
                    (cx - 20, top + 40)],
                   fill=hair_color + (255,))
    elif style == "messy":
        od.pieslice([cx - fw // 2 - 8, top - 16, cx + fw // 2 + 8, top + fh - 28],
                    180, 360, fill=hair_color + (255,))
        # Spikes
        for i, x_off in enumerate([-30, -10, 10, 28, -22, 18]):
            sy = top - 4 - (i % 2) * 6
            od.polygon([(cx + x_off - 8, top + 6),
                        (cx + x_off + 8, top + 6),
                        (cx + x_off, sy)],
                       fill=hair_color + (255,))
    elif style == "robe_hood":
        # Hooded look — large hood draping
        od.pieslice([cx - fw // 2 - 22, top - 28, cx + fw // 2 + 22, top + fh - 14],
                    180, 360, fill=hair_color + (255,))
    elif style == "short":
        od.pieslice([cx - fw // 2 - 4, top - 12, cx + fw // 2 + 4, top + fh - 36],
                    180, 360, fill=hair_color + (255,))
    elif style == "ghost":
        # Wispy hair / spirit
        od.pieslice([cx - fw // 2 - 6, top - 22, cx + fw // 2 + 6, top + fh - 24],
                    180, 360, fill=hair_color + (180,))


def _draw_glasses(od, cx, cy, fw, color=(60, 50, 80)):
    eye_y = cy + 6
    eye_w = fw // 5
    eye_h = int(fw // 3.5)
    for sgn in (-1, 1):
        ex = cx + sgn * (fw // 5)
        od.ellipse([ex - eye_w // 2 - 4, eye_y - eye_h // 2 - 2,
                    ex + eye_w // 2 + 4, eye_y + eye_h // 2 + 2],
                   outline=color + (255,), width=3)
    od.line([cx - fw // 5 + eye_w // 2 + 4, eye_y,
             cx + fw // 5 - eye_w // 2 - 4, eye_y],
            fill=color + (255,), width=2)


def _draw_body(od, cx, cy, fw, fh, robe_color):
    """Simple shoulders/robe collar below face."""
    body_top = cy + fh // 2 - 4
    body_h = P_H - body_top - 4
    od.polygon([(cx - 110, body_top + body_h),
                (cx - 80, body_top + 8),
                (cx - fw // 4, body_top + 4),
                (cx + fw // 4, body_top + 4),
                (cx + 80, body_top + 8),
                (cx + 110, body_top + body_h)],
               fill=robe_color + (255,))
    # Collar accent
    od.polygon([(cx - 30, body_top + 4),
                (cx + 30, body_top + 4),
                (cx, body_top + 30)],
               fill=lerp_color(robe_color, (255, 240, 220), 0.5) + (255,))


def make_portrait(out_path, *, bg_top, bg_bot,
                  hair_color, hair_style="bangs",
                  eye_color=(40, 50, 110),
                  skin=(255, 220, 198),
                  robe_color=(80, 70, 130),
                  smile=True, blush=False, glasses=False,
                  ghost_alpha=False):
    """One canonical anime-suggestive bust portrait."""
    img = vgradient(P_W, P_H, bg_top, bg_bot)
    img = add_stars(img, count=40, color=(255, 240, 220), alpha_max=180, seed=hash(out_path) & 0xFFFF)
    od = ImageDraw.Draw(img)

    cx, cy = P_W // 2, int(P_H * 0.40)
    fw = int(P_W * 0.55)
    fh = int(fw * 1.20)

    # Body first (so robe sits behind hair locks)
    _draw_body(od, cx, cy, fw, fh, robe_color)

    # Face
    _draw_face(od, cx, cy, fw, fh, skin)

    if blush:
        _draw_blush(od, cx, cy, fw)

    # Eyes
    _draw_eyes(od, cx, cy, fw, eye_color=eye_color)

    if glasses:
        _draw_glasses(od, cx, cy, fw)

    _draw_mouth(od, cx, cy, fw, smile=smile)

    # Hair on top
    _draw_hair(od, cx, cy, fw, fh, hair_color, style=hair_style)

    if ghost_alpha:
        # Apply soft transparency for ghost-type bosses
        alpha = img.split()[-1].point(lambda a: int(a * 0.78))
        img.putalpha(alpha)

    img = vignette(img, strength=0.20)
    img.save(out_path)


# ─── UI elements ─────────────────────────────────────────────────────

def make_card_frame(out_path, color, accent, w=200, h=280):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(img)
    # Outer rounded rect
    radius = 18
    od.rounded_rectangle([2, 2, w - 2, h - 2], radius=radius,
                         outline=color + (255,), width=4)
    od.rounded_rectangle([8, 8, w - 8, h - 8], radius=radius - 4,
                         outline=accent + (200,), width=2)
    # Corner gem
    gx, gy = w - 22, 22
    od.ellipse([gx - 10, gy - 10, gx + 10, gy + 10], fill=accent + (255,))
    od.ellipse([gx - 5, gy - 5, gx, gy], fill=(255, 255, 255, 200))
    img.save(out_path)


def make_hp_fill(out_path, color, w=256, h=24):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(img)
    od.rounded_rectangle([0, 0, w, h], radius=h // 2, fill=color + (255,))
    # Highlight strip
    od.rounded_rectangle([0, 2, w, h // 2], radius=h // 3,
                         fill=lerp_color(color, (255, 255, 255), 0.35) + (180,))
    img.save(out_path)


def make_button_bg(out_path, color, accent, w=240, h=64):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(img)
    od.rounded_rectangle([0, 0, w, h], radius=h // 2,
                         fill=color + (255,), outline=accent + (255,), width=3)
    od.rounded_rectangle([4, 3, w - 4, h // 2 + 2], radius=h // 3,
                         fill=lerp_color(color, (255, 255, 255), 0.30) + (140,))
    img.save(out_path)


def make_sparkle(out_path, w=64, h=64, color=(255, 240, 200)):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    # 4-point star
    od.polygon([(cx, 4), (cx + 6, cy - 6),
                (w - 4, cy), (cx + 6, cy + 6),
                (cx, h - 4), (cx - 6, cy + 6),
                (4, cy), (cx - 6, cy - 6)],
               fill=color + (240,))
    od.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(255, 255, 255, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(out_path)


# ─── Driver ──────────────────────────────────────────────────────────

PORTRAITS = {
    # NPCs
    "player": dict(
        bg_top=(170, 200, 255), bg_bot=(60, 80, 160),
        hair_color=(70, 60, 130), hair_style="bangs",
        eye_color=(40, 80, 160),
        robe_color=(90, 130, 200),
        smile=True, blush=True),
    "mentor_word": dict(
        bg_top=(255, 230, 180), bg_bot=(140, 110, 70),
        hair_color=(120, 80, 50), hair_style="long",
        eye_color=(70, 50, 30),
        robe_color=(180, 130, 70),
        smile=True, glasses=True),
    "elder": dict(
        bg_top=(220, 200, 240), bg_bot=(100, 80, 140),
        hair_color=(220, 220, 230), hair_style="long",
        eye_color=(80, 60, 110),
        robe_color=(110, 90, 150),
        smile=True),
    # 0F bosses
    "boss_letter_chaos": dict(
        bg_top=(255, 220, 170), bg_bot=(120, 60, 50),
        hair_color=(210, 180, 140), hair_style="messy",
        eye_color=(180, 110, 50),
        skin=(245, 230, 215),
        robe_color=(150, 90, 50),
        smile=False, ghost_alpha=True),
    "boss_phonics_spirit": dict(
        bg_top=(220, 240, 255), bg_bot=(80, 130, 180),
        hair_color=(160, 200, 230), hair_style="long",
        eye_color=(80, 140, 200),
        skin=(240, 245, 250),
        robe_color=(120, 170, 220),
        smile=False, ghost_alpha=True),
    "boss_letter_warden": dict(
        bg_top=(255, 200, 130), bg_bot=(140, 80, 40),
        hair_color=(80, 50, 30), hair_style="short",
        eye_color=(180, 130, 50),
        robe_color=(180, 120, 60),
        smile=False, glasses=True),
    # 1F bosses
    "boss_fog_whisperer": dict(
        bg_top=(200, 200, 220), bg_bot=(70, 70, 110),
        hair_color=(190, 200, 220), hair_style="ghost",
        eye_color=(120, 130, 170),
        skin=(220, 225, 235),
        robe_color=(90, 95, 130),
        smile=False, ghost_alpha=True),
    "boss_silent_sigher": dict(
        bg_top=(170, 180, 220), bg_bot=(40, 50, 90),
        hair_color=(80, 90, 130), hair_style="long",
        eye_color=(60, 80, 130),
        skin=(225, 220, 230),
        robe_color=(60, 70, 110),
        smile=False, ghost_alpha=True),
    "boss_librarian": dict(
        bg_top=(220, 200, 255), bg_bot=(70, 50, 130),
        hair_color=(90, 70, 130), hair_style="long",
        eye_color=(120, 80, 200),
        robe_color=(110, 80, 170),
        smile=False, glasses=True),
    # 2F bosses
    "boss_family_scatter": dict(
        bg_top=(255, 200, 200), bg_bot=(140, 80, 100),
        hair_color=(170, 100, 130), hair_style="messy",
        eye_color=(180, 80, 110),
        skin=(245, 220, 220),
        robe_color=(160, 90, 110),
        smile=False, ghost_alpha=True),
    "boss_body_lost": dict(
        bg_top=(220, 220, 200), bg_bot=(110, 100, 80),
        hair_color=(160, 150, 130), hair_style="ghost",
        eye_color=(120, 100, 70),
        skin=(235, 225, 215),
        robe_color=(140, 130, 100),
        smile=False, ghost_alpha=True),
    "boss_family_guardian": dict(
        bg_top=(255, 180, 180), bg_bot=(120, 50, 80),
        hair_color=(60, 40, 50), hair_style="long",
        eye_color=(180, 60, 80),
        robe_color=(160, 60, 90),
        smile=False),
}

# Enemy portraits (smaller cast, simpler styling)
ENEMIES = {
    "letter_wisp": dict(bg_top=(255, 220, 180), bg_bot=(120, 70, 60),
                       hair_color=(220, 200, 160), hair_style="ghost",
                       eye_color=(180, 110, 60),
                       skin=(245, 230, 210),
                       robe_color=(170, 130, 80),
                       smile=False, ghost_alpha=True),
    "phonics_phantom": dict(bg_top=(220, 220, 250), bg_bot=(80, 100, 160),
                           hair_color=(180, 200, 230), hair_style="ghost",
                           eye_color=(100, 130, 200),
                           skin=(235, 240, 248),
                           robe_color=(130, 160, 210),
                           smile=False, ghost_alpha=True),
    "library_dust": dict(bg_top=(220, 200, 240), bg_bot=(80, 60, 130),
                        hair_color=(140, 110, 180), hair_style="ghost",
                        eye_color=(110, 80, 170),
                        robe_color=(110, 90, 160),
                        smile=False, ghost_alpha=True),
    "wandering_word": dict(bg_top=(200, 220, 240), bg_bot=(70, 90, 140),
                          hair_color=(120, 140, 180), hair_style="messy",
                          eye_color=(80, 100, 150),
                          robe_color=(100, 120, 170),
                          smile=False, ghost_alpha=True),
    "bookworm": dict(bg_top=(220, 200, 180), bg_bot=(110, 80, 60),
                    hair_color=(110, 80, 50), hair_style="messy",
                    eye_color=(150, 100, 60),
                    robe_color=(140, 100, 70),
                    smile=False, glasses=True),
    "home_haunter": dict(bg_top=(255, 210, 210), bg_bot=(140, 80, 100),
                        hair_color=(170, 110, 130), hair_style="ghost",
                        eye_color=(180, 90, 110),
                        robe_color=(160, 100, 120),
                        smile=False, ghost_alpha=True),
    "body_blur": dict(bg_top=(220, 220, 200), bg_bot=(120, 110, 90),
                     hair_color=(160, 150, 130), hair_style="ghost",
                     eye_color=(130, 110, 80),
                     robe_color=(140, 130, 110),
                     smile=False, ghost_alpha=True),
    "pronoun_pest": dict(bg_top=(220, 200, 220), bg_bot=(110, 70, 120),
                        hair_color=(160, 120, 170), hair_style="messy",
                        eye_color=(140, 80, 170),
                        robe_color=(150, 100, 160),
                        smile=False),
}


def main():
    print(f"Output dir: {OUT}")
    BG_DIR.mkdir(parents=True, exist_ok=True)
    P_DIR.mkdir(parents=True, exist_ok=True)
    UI_DIR.mkdir(parents=True, exist_ok=True)
    PART_DIR.mkdir(parents=True, exist_ok=True)

    # Backgrounds
    print("Backgrounds...")
    bg_main_menu().save(BG_DIR / "main_menu.png")
    bg_city().save(BG_DIR / "city.png")
    bg_floor_0F().save(BG_DIR / "floor_0F.png")
    bg_floor_1F().save(BG_DIR / "floor_1F.png")
    bg_floor_2F().save(BG_DIR / "floor_2F.png")
    bg_boss_battle().save(BG_DIR / "boss_battle.png")
    bg_settlement().save(BG_DIR / "settlement.png")

    # Portraits (NPCs + bosses)
    print("Portraits...")
    for name, kwargs in PORTRAITS.items():
        make_portrait(P_DIR / f"{name}.png", **kwargs)
    for name, kwargs in ENEMIES.items():
        make_portrait(P_DIR / f"{name}.png", **kwargs)

    # UI
    print("UI...")
    make_card_frame(UI_DIR / "card_frame_common.png", (130, 140, 150), (200, 210, 220))
    make_card_frame(UI_DIR / "card_frame_rare.png", (90, 130, 200), (180, 220, 255))
    make_card_frame(UI_DIR / "card_frame_legendary.png", (200, 150, 70), (255, 230, 150))
    make_button_bg(UI_DIR / "button_normal.png", (110, 130, 200), (220, 230, 255))
    make_button_bg(UI_DIR / "button_accent.png", (220, 160, 80), (255, 230, 170))
    make_hp_fill(UI_DIR / "hp_fill_player.png", (90, 200, 120))
    make_hp_fill(UI_DIR / "hp_fill_enemy.png", (210, 90, 110))

    # Particles
    print("Particles...")
    make_sparkle(PART_DIR / "sparkle.png")
    make_sparkle(PART_DIR / "sparkle_blue.png", color=(180, 220, 255))
    make_sparkle(PART_DIR / "sparkle_pink.png", color=(255, 200, 220))

    print("Done.")


if __name__ == "__main__":
    main()
