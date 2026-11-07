"""Uygulama simgesi: tam siyah zemin, mavi gradyanla üstten görünen dört pervaneli drone ve ses dalgaları.

    python tool/make_icon.py      (depo kökünde; Pillow gerekir)

Renkler fizix.ai gradyanı: #47C9F9 → #325BDA. iOS simgesi saydamlık içermez (RGB);
Android simgesi köşeleri yuvarlatılmış RGBA.
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
S = 4096  # çizim çözünürlüğü (sonra küçültülür → yumuşak kenarlar)
C1, C2 = (0x47, 0xC9, 0xF9), (0x32, 0x5B, 0xDA)


def gradient(size):
    """Sol üstten sağ alta çapraz gradyan."""
    w = h = size
    g = Image.new('RGB', (w, h))
    px = g.load()
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            t = min(1.0, max(0.0, (x + y) / (w + h) * 1.25 - 0.1))
            c = tuple(int(C1[i] + (C2[i] - C1[i]) * t) for i in range(3))
            for dy in range(4):
                for dx in range(4):
                    if x + dx < w and y + dy < h:
                        px[x + dx, y + dy] = c
    return g


def mask():
    m = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(m)
    cx, cy = S * 0.5, S * 0.57
    arm = S * 0.17  # merkezden rotor merkezine
    rr = S * 0.085   # rotor halkası yarıçapı
    lw = int(S * 0.022)
    rots = []
    for a in (45, 135, 225, 315):
        r = math.radians(a)
        rots.append((cx + arm * math.cos(r), cy + arm * math.sin(r)))
    # kollar
    for x, y in rots:
        d.line([(cx, cy), (x, y)], fill=255, width=int(lw * 1.25))
    # gövde
    bw, bh = S * 0.11, S * 0.11
    d.rounded_rectangle([cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2], radius=S * 0.035, fill=255)
    # rotor halkaları ve göbekleri
    for x, y in rots:
        d.ellipse([x - rr, y - rr, x + rr, y + rr], outline=255, width=lw)
        d.ellipse([x - S * 0.018, y - S * 0.018, x + S * 0.018, y + S * 0.018], fill=255)
    # ses dalgaları (üstte, dışa doğru incelen)
    for k, (rad, wd) in enumerate([(0.29, 0.02), (0.345, 0.017), (0.40, 0.014)]):
        R = S * rad
        box = [cx - R, cy - R, cx + R, cy + R]
        d.arc(box, start=-128 + 3 * k, end=-52 - 3 * k, fill=255, width=int(S * wd))
    return m


def main():
    m = mask()
    g = gradient(S)
    glow = m.filter(ImageFilter.GaussianBlur(S * 0.03))
    glow = ImageChops.multiply(glow, Image.new('L', (S, S), 110))
    base = Image.new('RGB', (S, S), (0, 0, 0))
    base = Image.composite(g, base, glow)  # hafif mavi parıltı
    base = Image.composite(g, base, m)
    icon = base.resize((1024, 1024), Image.LANCZOS)

    icon.save(os.path.join(ROOT, 'assets/icon/icon-1024.png'))
    ios = os.path.join(ROOT, 'assets/icon/ios')
    for name in os.listdir(ios):
        if not name.endswith('.png'):
            continue
        sz = float(name.split('-')[2].split('x')[0])
        scale = int(name.split('@')[1][0])
        px = int(round(sz * scale))
        icon.resize((px, px), Image.LANCZOS).convert('RGB').save(os.path.join(ios, name))
    for d, px in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        im = icon.resize((px, px), Image.LANCZOS).convert('RGBA')
        rm = Image.new('L', (px * 4, px * 4), 0)
        ImageDraw.Draw(rm).rounded_rectangle([0, 0, px * 4 - 1, px * 4 - 1], radius=px * 4 * 0.22, fill=255)
        im.putalpha(rm.resize((px, px), Image.LANCZOS))
        im.save(os.path.join(ROOT, f'assets/icon/android/mipmap-{d}/ic_launcher.png'))
    print('simgeler yazıldı')


if __name__ == '__main__':
    main()
