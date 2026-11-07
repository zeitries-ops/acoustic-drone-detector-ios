"""Bildirim sesi: Mors kodunda iki kez SOS (··· −−− ···).

    python tool/make_sos.py      (depo kökünde; numpy gerekir)

1 kHz ana ton + 2 ve 3 kHz harmonikleri: telefon hoparlöründe keskin duyulur. Her bip 6 ms'lik
yumuşak giriş/çıkışla başlayıp biter (tıkırtı yapmaz). 22,05 kHz, 16 bit, tek kanal WAV:
Android (res/raw) ve iOS (Library/Sounds) ikisi de doğrudan çalar. Süre ~5 sn (iOS sınırı 30 sn).
"""
import os
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SR = 22050  # tonlar ≤ 3 kHz: 22 kHz yeterli, dosya yarı boyutta
U = 0.085  # Mors birimi (sn)


def tone(dur):
    t = np.arange(int(dur * SR)) / SR
    y = np.sin(2 * np.pi * 1000 * t) + 0.40 * np.sin(2 * np.pi * 2000 * t) + 0.20 * np.sin(2 * np.pi * 3000 * t)
    n = int(0.006 * SR)
    env = np.ones_like(y)
    ramp = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n))
    env[:n], env[-n:] = ramp, ramp[::-1]
    return y * env


def gap(units):
    return np.zeros(int(units * U * SR))


def letter(code):
    parts = []
    for i, c in enumerate(code):
        if i:
            parts.append(gap(1))
        parts.append(tone(U if c == '.' else 3 * U))
    return np.concatenate(parts)


def main():
    sos = np.concatenate([letter('...'), gap(3), letter('---'), gap(3), letter('...')])
    y = np.concatenate([gap(0.5), sos, gap(7), sos, gap(2)])
    y = y / np.abs(y).max() * 10 ** (-1 / 20)  # tepe −1 dBFS
    pcm = (y * 32767).astype('<i2').tobytes()
    out = [os.path.join(ROOT, 'packages/drone_audio/android/src/main/res/raw/drone_sos.wav'),
           os.path.join(ROOT, 'assets/sounds/drone_sos.wav')]
    for p in out:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with wave.open(p, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm)
    print(f'SOS sesi: {len(y) / SR:.1f} sn', out)


if __name__ == '__main__':
    main()
