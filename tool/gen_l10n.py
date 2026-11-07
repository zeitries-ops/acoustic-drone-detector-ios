#!/usr/bin/env python3
"""l10n/*.json → lib/l10n/strings.g.dart

Kaynak İngilizce (l10n/en.json). Her dil dosyası denetlenir:
  - eksik anahtar → hata (İngilizce yedek yalnızca çalışma zamanında güvenlik için)
  - fazladan anahtar, farklı {yer tutucu} kümesi → hata
  - ay listesi 12 öğe, tarih kalıbında {d} ve ({mon} ya da {m})
  - sekme etiketleri en fazla 11 karakter (alt sekme çubuğuna sığsın)
Kullanım:  python3 tool/gen_l10n.py          (yazar)
           python3 tool/gen_l10n.py --check  (yalnızca denetler; çıktı güncel değilse hata)
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'l10n'
OUT = ROOT / 'lib' / 'l10n' / 'strings.g.dart'
PLATFORM = ROOT / 'tool' / 'platform_l10n'
APP_NAME = 'Acoustic Drone Detector'  # lib/app/brand.dart kAppName

# iOS .lproj ve Android localeConfig adları
IOS_LPROJ = {'zh_Hant': 'zh-Hant'}
ANDROID_TAG = {'zh_Hant': 'zh-TW'}

# Uygulamadaki sıra (kullanıcının öncelik tablosu)
ORDER = ['en', 'uk', 'ru', 'pl', 'ro', 'he', 'ar', 'my', 'tr', 'de', 'fr', 'es', 'lt', 'lv', 'et', 'bg', 'fi', 'sv',
         'fa', 'az', 'hy', 'ka', 'zh_Hant', 'ja', 'ko', 'hi', 'ur']
TAB_KEYS = ['tabListen', 'tabSpectrum', 'tabLog', 'tabSettings']
PH = re.compile(r'\{([a-zA-Z]+)\}')


def dart_str(s):
    s = s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n')
    s = s.replace('\u2066', '\\u2066').replace('\u2069', '\\u2069')
    return "'" + s + "'"


# Sağdan sola dillerde sayı + birim parçaları soldan sağa yalıtılır ("Hz 450–90", "dBFS 38-" olmasın).
_RTL_ISO = re.compile(r'≈?\{\w+\}\s?(?:kHz|Hz|dBFS|dB)|≈\{\w+\}|\d+(?:[/–]\d+)?\s?(?:kHz|Hz)')


def rtl_isolate(v):
    return _RTL_ISO.sub(lambda m: '\u2066' + m.group(0) + '\u2069', v)


def load(code):
    with open(SRC / f'{code}.json', encoding='utf-8') as f:
        return json.load(f)


def main():
    check = '--check' in sys.argv
    files = {p.stem for p in SRC.glob('*.json')}
    missing_files = [c for c in ORDER if c not in files]
    extra_files = sorted(files - set(ORDER))
    errors = []
    if missing_files:
        errors.append(f'eksik dil dosyaları: {missing_files}')
    if extra_files:
        errors.append(f'listede olmayan dil dosyaları: {extra_files}')
    en = load('en')
    keys = [k for k in en if not k.startswith('@@')]
    langs = {}
    for code in [c for c in ORDER if c in files]:
        d = load(code)
        langs[code] = d
        if d.get('@@locale') != code:
            errors.append(f'{code}: @@locale = {d.get("@@locale")!r}')
        for meta in ['@@name', '@@rtl', '@@upper', '@@spacing', '@@group', '@@months', '@@date']:
            if meta not in d:
                errors.append(f'{code}: {meta} yok')
        if len(d.get('@@months', [])) != 12:
            errors.append(f'{code}: @@months 12 öğe değil')
        dp = d.get('@@date', '')
        if '{d}' not in dp or ('{mon}' not in dp and '{m}' not in dp):
            errors.append(f'{code}: @@date kalıbı {dp!r}')
        for k in keys:
            if k not in d:
                errors.append(f'{code}: eksik anahtar {k}')
                continue
            v = d[k]
            if not isinstance(v, str) or not v.strip():
                errors.append(f'{code}.{k}: boş')
                continue
            if set(PH.findall(v)) != set(PH.findall(en[k])):
                errors.append(f'{code}.{k}: yer tutucular {sorted(set(PH.findall(v)))} ≠ {sorted(set(PH.findall(en[k])))}')
        for k in d:
            if not k.startswith('@@') and k not in en:
                errors.append(f'{code}: fazladan anahtar {k}')
        for k in TAB_KEYS:
            if k in d and len(d[k]) > 11:
                errors.append(f'{code}.{k}: sekme etiketi çok uzun ({len(d[k])} > 11): {d[k]}')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        sys.exit(1)

    out = []
    w = out.append
    w('// ÜRETİLDİ: tool/gen_l10n.py — elle düzenleme; kaynak l10n/*.json.')
    w("part of 'strings.dart';")
    w('')
    w('const kLanguages = <String>[' + ', '.join(dart_str(c) for c in langs) + '];')
    w('')
    w('const kLanguageNames = <String, String>{')
    for c, d in langs.items():
        w(f'  {dart_str(c)}: {dart_str(d["@@name"])},')
    w('};')
    w('')
    w('const kRtl = <String>{' + ', '.join(dart_str(c) for c, d in langs.items() if d['@@rtl']) + '};')
    w('const kNoLetterSpacing = <String>{' + ', '.join(dart_str(c) for c, d in langs.items() if not d['@@spacing']) + '};')
    w('const kTurkicUpper = <String>{' + ', '.join(dart_str(c) for c, d in langs.items() if d['@@upper'] == 'turkic') + '};')
    w('const kGroupSeparator = <String, String>{')
    for c, d in langs.items():
        w(f'  {dart_str(c)}: {dart_str(d["@@group"])},')
    w('};')
    w('const kDatePattern = <String, String>{')
    for c, d in langs.items():
        w(f'  {dart_str(c)}: {dart_str(d["@@date"])},')
    w('};')
    w('const kMonths = <String, List<String>>{')
    for c, d in langs.items():
        w(f'  {dart_str(c)}: [' + ', '.join(dart_str(m) for m in d['@@months']) + '],')
    w('};')
    w('')
    w('const kTables = <String, Map<String, String>>{')
    for c, d in langs.items():
        w(f'  {dart_str(c)}: {{')
        for k in keys:
            v = rtl_isolate(d[k]) if d['@@rtl'] else d[k]
            w(f'    {dart_str(k)}: {dart_str(v)},')
        w('  },')
    w('};')
    w('')
    w('abstract class _Strings {')
    w('  String _s(String key);')
    w('  String _f(String key, Map<String, Object> args);')
    w('')
    for k in keys:
        en_v = en[k].replace('\n', ' ')
        ph = list(dict.fromkeys(PH.findall(en[k])))
        w(f'  /// {en_v}')
        if ph:
            params = ', '.join(f'required Object {p}' for p in ph)
            args = ', '.join(f"'{p}': {p}" for p in ph)
            w(f"  String {k}({{{params}}}) => _f('{k}', {{{args}}});")
        else:
            w(f"  String get {k} => _s('{k}');")
    w('}')
    text = '\n'.join(out) + '\n'

    # Platform dosyaları: iOS mikrofon izni metni (InfoPlist.strings) ve Android 13+ uygulama dili listesi
    platform = {}
    for c, d in langs.items():
        mic = d['micUsage'].replace('{app}', APP_NAME).replace('\\', '\\\\').replace('"', '\\"')
        platform[f'ios/{IOS_LPROJ.get(c, c)}.lproj/InfoPlist.strings'] = (
            f'/* {d["@@name"]} — tool/gen_l10n.py */\n"NSMicrophoneUsageDescription" = "{mic}";\n')
    platform['ios/languages.txt'] = '\n'.join(IOS_LPROJ.get(c, c) for c in langs) + '\n'
    platform['android/locales_config.xml'] = (
        '<?xml version="1.0" encoding="utf-8"?>\n<!-- tool/gen_l10n.py -->\n<locale-config xmlns:android="http://schemas.android.com/apk/res/android">\n'
        + ''.join(f'    <locale android:name="{ANDROID_TAG.get(c, c)}"/>\n' for c in langs) + '</locale-config>\n')

    if check:
        stale = [k for k, v in platform.items() if not (PLATFORM / k).exists() or (PLATFORM / k).read_text(encoding='utf-8') != v]
        if stale:
            print(f'tool/platform_l10n güncel değil ({len(stale)} dosya): python3 tool/gen_l10n.py', file=sys.stderr)
            sys.exit(1)
        if not OUT.exists() or OUT.read_text(encoding='utf-8') != text:
            print('lib/l10n/strings.g.dart güncel değil: python3 tool/gen_l10n.py', file=sys.stderr)
            sys.exit(1)
        print(f'tamam: {len(langs)} dil, {len(keys)} metin')
        return
    OUT.write_text(text, encoding='utf-8')
    for k, v in platform.items():
        (PLATFORM / k).parent.mkdir(parents=True, exist_ok=True)
        (PLATFORM / k).write_text(v, encoding='utf-8')
    print(f'{OUT.relative_to(ROOT)}: {len(langs)} dil, {len(keys)} metin')


if __name__ == '__main__':
    main()
