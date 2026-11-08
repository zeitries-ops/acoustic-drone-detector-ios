"""App Store ekran görüntülerini başlıklı (pazarlama) çerçeveye koyar.

Girdi:  store/app_store/screenshots/*.png   (uygulamanın ham ekranları, CI üretir)
Çıktı:  store/app_store/framed/*.png        (App Store Connect'e yüklenecek olanlar)

    python3 tool/make_store_shots.py

Boyutlar Apple'ın istediği gibi: iPhone 6,9" 1320×2868, iPad 13" 2064×2752 (dikey).
Başlık "Üst satır|Alt satır": üst satır uygulamadaki gibi mavi gradyan, alt satır beyaz.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'store' / 'app_store' / 'screenshots'
OUT = ROOT / 'store' / 'app_store' / 'framed'
FONTS = ROOT / 'assets' / 'fonts'

BG = (0, 0, 0)
INK = (244, 244, 245)
MUTED = (161, 161, 170)
LINE = (38, 38, 46)
GRAD = ((0x47, 0xC9, 0xF9), (0x32, 0x5B, 0xDA))  # theme.dart: Gradients.text
GLOW = (0x1F, 0x7F, 0xE0)

SHOTS = [
    # (kaynak, çıktı, başlık, alt metin)
    ('iphone_1_drone.png', 'iphone_1.png', 'Hear drones|before you see them',
     'On-device detection with an SOS alert, even in the background.'),
    ('iphone_2_spectrum.png', 'iphone_2.png', 'See the sound|of propellers',
     'The live spectrum shows the harmonic lines a drone makes.'),
    ('iphone_3_surroundings.png', 'iphone_3.png', 'Tuned|to where you are',
     'Indoors, City or Open area. Sensitivity adapts in one tap.'),
    ('iphone_4_log.png', 'iphone_4.png', 'Every detection|in your log',
     'Time, duration and frequency. Ignore devices that hum like a drone.'),
    ('iphone_5_settings.png', 'iphone_5.png', 'Private|by design',
     'Nothing is recorded or sent. No account, no ads, no tracking.'),
    ('ipad_1_landscape.png', 'ipad_1.png', 'Hear drones|before you see them',
     'On-device detection with an SOS alert, even in the background.'),
    ('ipad_2_spectrum.png', 'ipad_2.png', 'See the sound|of propellers',
     'The live spectrum shows the harmonic lines a drone makes.'),
    ('ipad_3_surroundings.png', 'ipad_3.png', 'Tuned|to where you are',
     'Indoors, City or Open area. Sensitivity adapts in one tap.'),
    ('ipad_4_settings.png', 'ipad_4.png', 'Private|by design',
     'Nothing is recorded or sent. No account, no ads, no tracking.'),
]


def font(name, size):
    return ImageFont.truetype(str(FONTS / f'Poppins-{name}.ttf'), size)


def gradient_text(canvas, xy, text, fnt):
    """Metni yatay mavi gradyanla çizer (uygulamadaki GradientText gibi)."""
    l, t, r, b = fnt.getbbox(text)
    w, h = r - l, b - t
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).text((-l, -t), text, font=fnt, fill=255)
    grad = Image.new('RGB', (w, h))
    gd = ImageDraw.Draw(grad)
    for x in range(w):
        k = x / max(1, w - 1)
        gd.line([(x, 0), (x, h)], fill=tuple(round(a + (b_ - a) * k) for a, b_ in zip(*GRAD)))
    canvas.paste(grad, (xy[0] + l, xy[1] + t), mask)


def wrap(text, fnt, width, draw):
    """Satırlara böler; iki satır olursa satırları dengeler (tek kelime alta düşmesin)."""
    words, lines, cur = text.split(), [], ''
    for w in words:
        test = f'{cur} {w}'.strip()
        if draw.textlength(test, font=fnt) <= width:
            cur = test
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    if len(lines) == 2:
        best = min(range(1, len(words)), key=lambda i: max(draw.textlength(' '.join(words[:i]), font=fnt),
                                                           draw.textlength(' '.join(words[i:]), font=fnt)))
        lines = [' '.join(words[:best]), ' '.join(words[best:])]
    return lines


def crop_content(im, skip_left):
    """iPad ekranında içerik ortada küçük kalır: boş siyah alanı (ve yatayda yan rayı) kırp."""
    g = im.convert('L').point(lambda v: 255 if v > 24 else 0)
    box = g.crop((skip_left, 0, im.width, im.height)).getbbox()
    if not box:
        return im
    pad = 70
    l, t, r, b = box[0] + skip_left - pad, box[1] - pad, box[2] + skip_left + pad, box[3] + pad
    return im.crop((max(0, l), max(0, t), min(im.width, r), min(im.height, b)))


def rounded(im, radius):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=radius, fill=255)
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def make(src, dst, title, sub, ipad):
    W, H = (2064, 2752) if ipad else (1320, 2868)
    canvas = Image.new('RGB', (W, H), BG)

    # Üstte hafif mavi parıltı
    glow = Image.new('RGB', (W, H), BG)
    ImageDraw.Draw(glow).ellipse([W * -0.2, H * -0.25, W * 1.2, H * 0.32], fill=tuple(int(c * 0.30) for c in GLOW))
    canvas = Image.blend(canvas, glow.filter(ImageFilter.GaussianBlur(W // 6)), 1.0)
    d = ImageDraw.Draw(canvas)

    scale = W / 1320 if not ipad else 1.45
    top = int(150 * scale)
    t1, t2 = title.split('|')
    ft = font('ExtraBold', int(104 * scale))
    fs = font('Regular', int(44 * scale))
    lh = int(ft.size * 1.18)

    for i, (txt, grad) in enumerate([(t1, True), (t2, False)]):
        x = (W - d.textlength(txt, font=ft)) // 2
        y = top + i * lh
        if grad:
            gradient_text(canvas, (int(x), y), txt, ft)
        else:
            d.text((x, y), txt, font=ft, fill=INK)
    y = top + 2 * lh + int(24 * scale)
    for line in wrap(sub, fs, W * 0.80, d):
        d.text(((W - d.textlength(line, font=fs)) // 2, y), line, font=fs, fill=MUTED)
        y += int(fs.size * 1.45)

    # Ekran görüntüsü: kalan alana sığdır, yuvarlak köşe + ince çerçeve
    shot = Image.open(SRC / src).convert('RGB')
    if ipad:
        shot = crop_content(shot, skip_left=220 if shot.width > shot.height else 0)
    area_top = y + int(70 * scale)
    margin = int(90 * scale)
    max_w, max_h = W - 2 * margin, H - area_top - int(90 * scale)
    k = min(max_w / shot.width, max_h / shot.height)
    sw, sh = int(shot.width * k), int(shot.height * k)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    radius = int(min(sw, sh) * 0.07)
    x0 = (W - sw) // 2
    y0 = area_top + (max_h - sh) // 2 if ipad else area_top
    # yumuşak gölge/parıltı
    halo = Image.new('L', (W, H), 0)
    ImageDraw.Draw(halo).rounded_rectangle([x0, y0, x0 + sw, y0 + sh], radius=radius, fill=110)
    halo = halo.filter(ImageFilter.GaussianBlur(int(40 * scale)))
    canvas.paste(Image.new('RGB', (W, H), tuple(int(c * 0.55) for c in GLOW)), (0, 0), halo)
    canvas.paste(rounded(shot, radius), (x0, y0), rounded(shot, radius))
    ImageDraw.Draw(canvas).rounded_rectangle([x0, y0, x0 + sw - 1, y0 + sh - 1], radius=radius, outline=LINE,
                                             width=max(2, int(3 * scale)))
    OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT / dst, optimize=True)
    return canvas.size


if __name__ == '__main__':
    for src, dst, title, sub in SHOTS:
        size = make(src, dst, title, sub, dst.startswith('ipad'))
        print(f'{dst}: {size[0]}×{size[1]}')
