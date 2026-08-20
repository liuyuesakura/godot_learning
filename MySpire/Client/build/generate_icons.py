"""
MySpire — 平台图标批量生成器
从项目 icon.svg 的设计（深蓝渐变背景 + 金色菱形）生成 Android / iOS 所需的全部 PNG 图标。
"""
from PIL import Image, ImageDraw, ImageFilter
import os
import sys

# ── 设计参数 ──────────────────────────────────────────
BG_DARK   = (8, 8, 20, 255)       # #080814
BG_LIGHT  = (26, 47, 92, 255)     # #1a2f5c
GOLD      = (201, 168, 76, 255)   # #c9a84c
GOLD_FILL = (201, 168, 76, 217)   # 85% opacity


def _radial_gradient(size: int) -> Image.Image:
    """径向渐变背景：上偏亮 → 边缘暗"""
    img = Image.new('RGBA', (size, size), BG_DARK)
    cx, cy = size // 2, int(size * 0.30)
    max_r = size
    for r in range(max_r, 0, -1):
        t = r / max_r
        cr = int(BG_LIGHT[0] * (1 - t) + BG_DARK[0] * t)
        cg = int(BG_LIGHT[1] * (1 - t) + BG_DARK[1] * t)
        cb = int(BG_LIGHT[2] * (1 - t) + BG_DARK[2] * t)
        bbox = [cx - r, cy - r, cx + r, cy + r]
        ImageDraw.Draw(img).ellipse(bbox, fill=(cr, cg, cb, 255))
    return img


def _rounded_mask(size: int, radius: int) -> Image.Image:
    """圆角遮罩"""
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=radius, fill=255
    )
    return mask


def create_icon(size: int, rounded: bool = True) -> Image.Image:
    """生成一枚图标：深蓝渐变背景 + 金色菱形"""
    img = _radial_gradient(size)
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    r_out = int(size * 0.38)
    r_in  = int(size * 0.22)
    sw    = max(2, size // 32)

    # 外菱形轮廓
    outer = [(cx, cy - r_out), (cx + r_out, cy), (cx, cy + r_out), (cx - r_out, cy)]
    draw.polygon(outer, outline=GOLD, width=sw)

    # 内菱形填充
    inner = [(cx, cy - r_in), (cx + r_in, cy), (cx, cy + r_in), (cx - r_in, cy)]
    draw.polygon(inner, fill=GOLD_FILL)

    if rounded and size >= 76:
        radius = int(size * 0.22)
        mask = _rounded_mask(size, radius)
        transparent = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        transparent.paste(img, (0, 0), mask)
        img = transparent

    return img


def create_adaptive_fg(size: int) -> Image.Image:
    """Android 自适应图标前景层（透明背景 + 金色菱形居中偏上）"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size // 2, int(size * 0.45)
    r_out = int(size * 0.25)
    r_in  = int(size * 0.15)
    sw    = max(3, size // 50)

    outer = [(cx, cy - r_out), (cx + r_out, cy), (cx, cy + r_out), (cx - r_out, cy)]
    draw.polygon(outer, outline=GOLD, width=sw)

    inner = [(cx, cy - r_in), (cx + r_in, cy), (cx, cy + r_in), (cx - r_in, cy)]
    draw.polygon(inner, fill=GOLD_FILL)

    return img


def create_adaptive_bg(size: int) -> Image.Image:
    """Android 自适应图标背景层（深蓝纯色）"""
    img = Image.new('RGBA', (size, size), BG_DARK)
    return img


# ── 图标规格表 ─────────────────────────────────────────
ANDROID_ICONS = {
    "icon_192":        (192,  "icon",    True),
    "adaptive_fg_432": (432,  "fg",      False),
    "adaptive_bg_432": (432,  "bg",      False),
}

IOS_ICONS = {
    "icon_40":   40,
    "icon_58":   58,
    "icon_60":   60,
    "icon_76":   76,
    "icon_80":   80,
    "icon_87":   87,
    "icon_120":  120,
    "icon_152":  152,
    "icon_167":  167,
    "icon_180":  180,
    "icon_1024": 1024,
}


def main() -> None:
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    android_dir = os.path.join(base_dir, "assets", "icons", "android")
    ios_dir     = os.path.join(base_dir, "assets", "icons", "ios")
    os.makedirs(android_dir, exist_ok=True)
    os.makedirs(ios_dir, exist_ok=True)

    # Android
    for name, (sz, kind, rounded) in ANDROID_ICONS.items():
        if kind == "icon":
            img = create_icon(sz, rounded=rounded)
        elif kind == "fg":
            img = create_adaptive_fg(sz)
        else:
            img = create_adaptive_bg(sz)
        path = os.path.join(android_dir, f"{name}.png")
        img.save(path, "PNG")
        print(f"  [Android] {name}.png  ({sz}x{sz})")

    # iOS
    for name, sz in IOS_ICONS.items():
        img = create_icon(sz, rounded=False)
        # iOS 图标不应有圆角遮罩（系统会自动裁切圆角）
        path = os.path.join(ios_dir, f"{name}.png")
        img.save(path, "PNG")
        print(f"  [iOS]     {name}.png  ({sz}x{sz})")

    print(f"\n所有图标已生成到：")
    print(f"  {android_dir}")
    print(f"  {ios_dir}")


if __name__ == "__main__":
    main()
