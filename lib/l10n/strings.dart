import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

part 'strings.g.dart';

/// Uygulama metinleri. Dil cihazın dilini izler (27 dil); desteklenmeyen dilde İngilizce.
/// Kaynak: l10n/*.json → tool/gen_l10n.py → strings.g.dart.
///
/// Rakamlar her dilde Latin (0–9): ölçümler ve saatler karışık rakam sistemiyle görünmesin.
class S extends _Strings {
  S._(this.code) : _t = kTables[code] ?? kTables['en']!;

  /// Dil kodu: 'en', 'tr', 'zh_Hant' …
  final String code;
  final Map<String, String> _t;

  static final Map<String, S> _cache = {};

  static S forCode(String code) => _cache.putIfAbsent(code, () => S._(kTables.containsKey(code) ? code : 'en'));

  /// Bağlamı olmayan yerler (Monitor, bildirimler, biçim yardımcıları) için son yüklenen dil.
  static S current = forCode('en');

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? current;

  static const LocalizationsDelegate<S> delegate = _Delegate();

  static final List<Locale> supportedLocales = [for (final c in kLanguages) localeOf(c)];

  static Locale localeOf(String code) => code == 'zh_Hant'
      ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')
      : Locale(code);

  /// Cihaz dilinden uygulama dili: eski İbranice kodu (iw) da tanınır; Çince her zaman Geleneksel.
  static String? codeFor(Locale l) {
    var lang = l.languageCode.toLowerCase();
    if (lang == 'iw') lang = 'he';
    if (lang == 'zh') return 'zh_Hant';
    return kTables.containsKey(lang) ? lang : null;
  }

  /// MaterialApp.localeListResolutionCallback: tercih sırasındaki ilk desteklenen dil.
  static Locale resolve(List<Locale>? preferred, Iterable<Locale> supported) {
    for (final l in preferred ?? const <Locale>[]) {
      final c = codeFor(l);
      if (c != null) return localeOf(c);
    }
    return const Locale('en');
  }

  bool get isRtl => kRtl.contains(code);

  /// Arap, Devanagari ve Birman yazılarında harf aralığı bitişik harfleri koparır.
  bool get letterSpacing => !kNoLetterSpacing.contains(code);

  @override
  String _s(String key) => _t[key] ?? kTables['en']![key] ?? key;

  @override
  String _f(String key, Map<String, Object> args) {
    var s = _s(key);
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  /// Büyük harf: Türkçe ve Azericede i → İ, ı → I.
  String upper(String s) {
    if (kTurkicUpper.contains(code)) s = s.replaceAll('i', 'İ').replaceAll('ı', 'I');
    return s.toUpperCase();
  }

  /// Binlik ayraçlı tam sayı (6,360 · 6.360 · 6 360).
  String thousands(num v) {
    final n = v.round();
    final s = n.abs().toString();
    final sep = kGroupSeparator[code] ?? ',';
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(sep);
      b.write(s[i]);
    }
    return b.toString();
  }

  String pct(num v) => percent(v: v.round());

  /// Sağdan sola dillerde sayı + birim ("-38 dBFS", "90–450 Hz") soldan sağa kalsın: yön yalıtımı.
  String ltr(String s) => isRtl ? '\u2066$s\u2069' : s;

  /// Kısa tarih: "Nov 5", "5 нояб.", "11月5日".
  String date(DateTime t) => (kDatePattern[code] ?? '{mon} {d}')
      .replaceAll('{mon}', (kMonths[code] ?? kMonths['en']!)[t.month - 1])
      .replaceAll('{m}', '${t.month}')
      .replaceAll('{d}', '${t.day}');

  String duration(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final h = m ~/ 60;
    if (h > 0) return durHM(h: h, m: m % 60);
    return m > 0 ? durMS(m: m, s: s % 60) : durS(s: s);
  }
}

class _Delegate extends LocalizationsDelegate<S> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) => S.codeFor(locale) != null;

  @override
  Future<S> load(Locale locale) {
    final s = S.forCode(S.codeFor(locale) ?? 'en');
    S.current = s;
    return SynchronousFuture<S>(s);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<S> old) => false;
}
