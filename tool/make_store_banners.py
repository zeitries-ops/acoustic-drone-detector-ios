"""App Store 'Header' (3840x1646) and 'Search Results' (3840x2560) assets from the raw screenshots."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(sys.argv[1]); OUT = Path(sys.argv[2]); OUT.mkdir(parents=True, exist_ok=True)
SRC = REPO / 'store/app_store/screenshots'; FONTS = REPO / 'assets/fonts'
INK, MUTED, LINE = (244, 244, 245), (161, 161, 170), (38, 38, 46)
G1, G2 = (0x47, 0xC9, 0xF9), (0x32, 0x5B, 0xDA)
GLOW = (0x1F, 0x7F, 0xE0)

def font(n, s): return ImageFont.truetype(str(FONTS / f'Poppins-{n}.ttf'), s)

def grad_text(c, xy, text, f):
    l, t, r, b = f.getbbox(text); w, h = r - l, b - t
    m = Image.new('L', (w, h)); ImageDraw.Draw(m).text((-l, -t), text, font=f, fill=255)
    g = Image.new('RGB', (w, h)); gd = ImageDraw.Draw(g)
    for x in range(w):
        k = x / max(1, w - 1); gd.line([(x, 0), (x, h)], fill=tuple(round(a + (bb - a) * k) for a, bb in zip(G1, G2)))
    c.paste(g, (xy[0] + l, xy[1] + t), m)

def phone(shot, h):
    im = Image.open(SRC / shot).convert('RGB'); k = h / im.height
    im = im.resize((int(im.width * k), h), Image.LANCZOS)
    r = int(im.width * 0.11)
    m = Image.new('L', im.size); ImageDraw.Draw(m).rounded_rectangle([0, 0, im.width - 1, im.height - 1], r, fill=255)
    bez = int(h * 0.014)
    body = Image.new('RGBA', (im.width + 2 * bez, im.height + 2 * bez), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle([0, 0, body.width - 1, body.height - 1], r + bez, fill=(20, 20, 24, 255), outline=(70, 70, 82, 255), width=max(3, bez // 3))
    body.paste(im, (bez, bez), m)
    return body

def background(W, H):
    c = Image.new('RGB', (W, H), (0, 0, 0))
    glow = Image.new('RGB', (W, H), (0, 0, 0)); d = ImageDraw.Draw(glow)
    d.ellipse([W * 0.45, -H * 0.4, W * 1.25, H * 1.1], fill=tuple(int(v * 0.35) for v in GLOW))
    d.ellipse([-W * 0.25, H * 0.55, W * 0.45, H * 1.6], fill=tuple(int(v * 0.18) for v in GLOW))
    return Image.blend(c, glow.filter(ImageFilter.GaussianBlur(W // 10)), 1.0)

def chips(c, x, y, items, size, maxw):
    d = ImageDraw.Draw(c); f = font('Medium', size); pad = int(size * 0.7); gap = int(size * 0.55); cx, cy = x, y
    h = int(size * 2.2)
    for it in items:
        w = int(d.textlength(it, font=f)) + 2 * pad
        if cx + w > x + maxw: cx = x; cy += h + gap
        d.rounded_rectangle([cx, cy, cx + w, cy + h], h // 2, fill=(14, 22, 34), outline=(40, 90, 150), width=max(2, size // 18))
        d.text((cx + pad, cy + (h - size * 1.25) / 2), it, font=f, fill=INK)
        cx += w + gap
    return cy + h

FEATURES = ['Live FFT spectrum', 'On-device AI (YAMNet)', 'Rotor speed (RPM)', 'SOS alerts in background',
            'Nothing recorded', '27 languages']

def make(W, H, name, phones, title_size, sub_size, chip_size):
    c = background(W, H); d = ImageDraw.Draw(c)
    left = int(W * 0.055); textw = int(W * 0.44)
    ft, fs = font('ExtraBold', title_size), font('Regular', sub_size)
    lines = [('Hear drones', True), ('before you see them', False)]
    block_h = len(lines) * int(title_size * 1.15) + int(sub_size * 1.6) * 2 + int(chip_size * 2.2) * 2 + int(H * 0.08)
    y = (H - block_h) // 2
    for t, g in lines:
        (grad_text(c, (left, y), t, ft) if g else d.text((left, y), t, font=ft, fill=INK)); y += int(title_size * 1.15)
    y += int(sub_size * 0.5)
    for s in ['Acoustic drone detection on your iPhone and iPad.', 'Everything runs on the device.']:
        d.text((left, y), s, font=fs, fill=MUTED); y += int(sub_size * 1.45)
    y += int(sub_size * 0.9)
    chips(c, left, y, FEATURES, chip_size, textw)
    # phones on the right: size them so all fit inside the right area
    area_x0, area_x1 = int(W * 0.53), int(W * 0.97)
    ar = Image.open(SRC / phones[0]).width / Image.open(SRC / phones[0]).height
    n = len(phones); overlap = 0.80
    ph = int(min(H * 0.84, (area_x1 - area_x0) / (ar * 1.03 * (1 + (n - 1) * overlap))))
    imgs = [phone(p, ph) for p in phones]
    step = int(imgs[0].width * overlap)
    total = imgs[0].width + step * (n - 1)
    base_x = area_x0 + ((area_x1 - area_x0) - total) // 2
    order = list(range(n)); mid = n // 2
    order = [i for i in order if i != mid] + [mid]  # middle phone on top
    for i in order:
        im = imgs[i]
        top = (H - im.height) // 2 + (0 if i == mid else int(H * 0.035))
        x = base_x + i * step
        shadow = Image.new('L', (W, H)); ImageDraw.Draw(shadow).rounded_rectangle([x, top, x + im.width, top + im.height], im.width // 8, fill=170)
        c.paste((0, 0, 0), (0, 0), shadow.filter(ImageFilter.GaussianBlur(W // 140)))
        c.paste(im, (x, top), im)
    c.save(OUT / name, optimize=True)
    print(name, c.size)

make(3840, 1646, 'header_3840x1646.png', ['iphone_2_spectrum.png', 'iphone_1_drone.png', 'iphone_4_log.png'], 150, 58, 46)
make(3840, 2560, 'search_3840x2560.png', ['iphone_2_spectrum.png', 'iphone_1_drone.png', 'iphone_4_log.png'], 168, 64, 54)
