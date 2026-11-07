import 'package:flutter/material.dart';

/// Yazı ailesi (assets/fonts, SIL Open Font License).
const kFont = 'Poppins';

/// Poppins'te olmayan yazılar (Arapça, Kiril, CJK …) için yedek aileler. Uygulamada bu adlarla yazı tipi
/// paketlenmez; cihazın sistem yazı tipine düşülür. Ekran görüntüsü testleri bu adlarla Noto yükler.
const kFontFallback = <String>['NotoSansArabic', 'NotoSans'];

/// Tasarım belirteçleri. fizix.ai görsel dili: siyah zemin, koyu kartlar, ince gri kenarlık,
/// mavi gradyan vurgu ve iki tonlu başlıklar. Zemin tam siyah (#000000): AMOLED ekranlarda bu pikseller
/// kapalı kalır, pil harcamaz. Uygulama tek (koyu) temadır.
@immutable
class DkColors extends ThemeExtension<DkColors> {
  const DkColors({
    required this.bg,
    required this.surface,
    required this.surfaceHi,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.brand,
    required this.brandDeep,
    required this.purple,
    required this.alert,
    required this.scope,
    required this.accent,
    required this.accentInk,
    required this.ok,
    required this.warn,
    required this.okSoft,
    required this.warnSoft,
    required this.alertSoft,
    required this.scopeInk,
  });

  /// Sayfa zemini (tam siyah)
  final Color bg;

  /// Kart zemini
  final Color surface;

  /// Seçili satır ve ikincil buton zemini
  final Color surfaceHi;
  final Color line;
  final Color lineStrong;

  /// Ana metin
  final Color ink;
  final Color muted;
  final Color faint;

  /// Vurgu: gradyanın açık ve koyu ucu
  final Color brand;
  final Color brandDeep;

  /// İkincil vurgu (yoksayılan sesler)
  final Color purple;

  /// Drone uyarısı (anlamsal renk)
  final Color alert;

  /// Spektrum zemini
  final Color scope;

  // Dinle ekranı ilk v2 renklerini korur: mavi ana buton, yeşil/sarı/kırmızı durum kutusu.
  final Color accent;
  final Color accentInk;
  final Color ok;
  final Color warn;
  final Color okSoft;
  final Color warnSoft;
  final Color alertSoft;
  final Color scopeInk;

  static const brandSet = DkColors(
    bg: Color(0xFF000000),
    surface: Color(0xFF0E0E11),
    surfaceHi: Color(0xFF1C1C21),
    line: Color(0xFF26262E),
    lineStrong: Color(0xFF3A3A45),
    ink: Color(0xFFF4F4F5),
    muted: Color(0xFFA1A1AA),
    faint: Color(0xFF71717A),
    brand: Color(0xFF2AB1EB),
    brandDeep: Color(0xFF1F7FE0),
    purple: Color(0xFFB447EB),
    alert: Color(0xFFFF6B60),
    scope: Color(0xFF090D12),
    accent: Color(0xFF8CA3FF),
    accentInk: Color(0xFF0A1022),
    ok: Color(0xFF3DC28B),
    warn: Color(0xFFF0AE3A),
    okSoft: Color(0xFF14322A),
    warnSoft: Color(0xFF382A12),
    alertSoft: Color(0xFF3D1B19),
    scopeInk: Color(0xFFAEB9C3),
  );

  /// Buton ve vurgu dolgusu (fizix: 135°, #2AB1EB → #1F7FE0).
  static const fill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2AB1EB), Color(0xFF1F7FE0)],
  );

  /// Başlık yazı gradyanı (fizix: 90°, #47C9F9 → #325BDA).
  static const text = LinearGradient(colors: [Color(0xFF47C9F9), Color(0xFF325BDA)]);

  @override
  DkColors copyWith() => this;

  @override
  DkColors lerp(ThemeExtension<DkColors>? other, double t) => this;
}

extension DkColorsX on BuildContext {
  DkColors get dk => Theme.of(this).extension<DkColors>()!;
}

ThemeData buildTheme() {
  const c = DkColors.brandSet;
  final scheme = ColorScheme.fromSeed(seedColor: c.brand, brightness: Brightness.dark).copyWith(
    primary: c.brand,
    onPrimary: Colors.white,
    secondary: c.purple,
    onSecondary: Colors.white,
    surface: c.surface,
    onSurface: c.ink,
    surfaceContainerHighest: c.surfaceHi,
    surfaceContainerHigh: c.surfaceHi,
    surfaceContainer: c.surface,
    outline: c.lineStrong,
    outlineVariant: c.line,
    error: c.alert,
  );
  final base = ThemeData(
      useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme, fontFamily: kFont, fontFamilyFallback: kFontFallback);
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    extensions: const [c],
    textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink, fontFamily: kFont),
    dividerColor: c.line,
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.line)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.brand,
      inactiveTrackColor: c.line,
      thumbColor: Colors.white,
      overlayColor: c.brand.withValues(alpha: 0.14),
      trackHeight: 4,
      activeTickMarkColor: Colors.white.withValues(alpha: 0.5),
      inactiveTickMarkColor: c.lineStrong,
      valueIndicatorColor: c.surfaceHi,
      valueIndicatorTextStyle: TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, color: c.ink, fontSize: 12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : c.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : c.surfaceHi),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : c.lineStrong),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.brand.withValues(alpha: 0.16),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: kFont,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? c.brand : c.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.brand : c.muted, size: 22),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.bg,
      indicatorColor: c.brand.withValues(alpha: 0.16),
      useIndicator: true,
      selectedIconTheme: IconThemeData(color: c.brand, size: 22),
      unselectedIconTheme: IconThemeData(color: c.muted, size: 22),
      selectedLabelTextStyle: TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 12, fontWeight: FontWeight.w600, color: c.brand),
      unselectedLabelTextStyle: TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 12, fontWeight: FontWeight.w500, color: c.muted),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.line)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.brand,
        textStyle: const TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.brand,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 14, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
    badgeTheme: BadgeThemeData(backgroundColor: c.brand, textColor: Colors.white),
  );
}
