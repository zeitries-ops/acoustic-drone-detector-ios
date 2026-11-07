import 'package:flutter/material.dart';

import '../app/brand.dart';
import '../app/theme.dart';
import '../l10n/strings.dart';

/// fizix.ai görsel dilinin uygulamadaki yapı taşları: iki tonlu başlıklar (ilk kelime mavi gradyan),
/// harf aralıklı küçük büyük harf etiketler, koyu kartlar, hap biçimli etiketler.

const tabular = [FontFeature.tabularFigures()];

/// Başlık: Poppins Bold, hafif sıkı.
TextStyle display(double size, Color color) => TextStyle(
      fontFamily: kFont,
      fontFamilyFallback: kFontFallback,
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: 1.15,
      letterSpacing: S.current.letterSpacing ? -0.02 * size : 0,
      color: color,
    );

/// Gövde metni.
TextStyle body(double size, Color color, {FontWeight weight = FontWeight.w400}) =>
    TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: size, height: 1.5, color: color, fontWeight: weight);

/// Küçük yazı: etiketler, ölçümler, ikincil satırlar (sabit genişlikli rakamlar).
TextStyle small(double size, Color color, {double spacing = 0, FontWeight weight = FontWeight.w400}) => TextStyle(
      fontFamily: kFont,
      fontFamilyFallback: kFontFallback,
      fontSize: size,
      letterSpacing: S.current.letterSpacing ? spacing : 0,
      color: color,
      fontWeight: weight,
      fontFeatures: tabular,
      height: 1.4,
    );

/// Etiketler için büyük harf (Türkçe/Azerice i → İ).
String upper(String s) => S.current.upper(s);

/// Metni marka gradyanıyla boyar.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style, this.gradient = DkColors.text, this.maxLines});
  final String text;
  final TextStyle style;
  final Gradient gradient;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => gradient.createShader(Offset.zero & r.size),
      child: Text(text, style: style.copyWith(color: Colors.white), maxLines: maxLines),
    );
  }
}

/// İki tonlu başlık: ilk kelime gradyan, gerisi düz ("Detection log").
class TwoToneTitle extends StatelessWidget {
  const TwoToneTitle(this.text, {super.key, this.size = 22});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final i = text.indexOf(' ');
    final first = i < 0 ? text : text.substring(0, i);
    final rest = i < 0 ? '' : text.substring(i);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        GradientText(first, style: display(size, dk.ink)),
        if (rest.isNotEmpty) Text(rest, style: display(size, dk.ink)),
      ],
    );
  }
}

/// Küçük, büyük harfli, aralıklı etiket — kartın üstünde marka renginde.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      upper(text),
      style: small(11.5, color ?? context.dk.brand, spacing: 1.6, weight: FontWeight.w600),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Bölüm başlığı: iki tonlu başlık ve solan çizgi.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    return Row(
      children: [
        // başlık önceliklidir; çizgi kalan yeri doldurur
        Flexible(flex: 6, child: TwoToneTitle(title, size: 24)),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [dk.lineStrong, dk.lineStrong.withValues(alpha: 0)]),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// Küçük, büyük harfli, aralıklı etiket (okuma değerlerinin üstü).
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      upper(text),
      style: small(11, color ?? context.dk.muted, spacing: 1.2, weight: FontWeight.w500),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// İki sütunlu sayfa düzeni: yatay telefon, iPad yatay ve geniş pencereler.
bool useTwoColumns(Size s) => s.width >= 540 && (s.width >= 900 || s.height < s.width * 0.75);

/// Sayfa kaydırılmaz: içerik doğal yüksekliğinde çizilir, sığmazsa (küçük ekran, büyük yazı) orantılı küçültülür.
/// İçerik `Expanded` içermemeli; genişlik kabın genişliğine sabitlenir.
class FitPage extends StatelessWidget {
  const FitPage({super.key, required this.child, this.alignment = Alignment.topCenter});
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    // Align(heightFactor: 1): tam genişlik, içerik yüksekliği; küçülen içerik yatayda ortalanır.
    return LayoutBuilder(
      builder: (context, c) => Align(
        alignment: alignment,
        heightFactor: 1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: SizedBox(width: c.maxWidth, child: child),
        ),
      ),
    );
  }
}

/// Dar kutucuk başlığı: birden çok kelime iki satıra sarılır; tek uzun kelime ortadan bölünmesin diye
/// tek satırda gerekirse küçültülür ("Multikopter", "Benachrichtigungen").
class TileTitle extends StatelessWidget {
  const TileTitle(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (text.trim().contains(' ')) {
      return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, style: style, maxLines: 1),
    );
  }
}

/// Sayfa başlığı: iki tonlu başlık, sağda isteğe bağlı durum hapı.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: TwoToneTitle(title, size: 26),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// Kart: koyu zemin, ince kenarlık.
class BrandCard extends StatelessWidget {
  const BrandCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    // Material: içindeki ListTile ve InkWell dokunma efektlerini kartın üstüne çizebilsin.
    return Material(
      color: dk.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor ?? dk.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Bölüm kartı: etiket + iki tonlu başlık + içerik.
class Panel extends StatelessWidget {
  const Panel({super.key, this.label, this.title, this.trailing, required this.children});
  final String? label;
  final String? title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null || trailing != null)
            Row(
              children: [
                Expanded(child: label != null ? Kicker(label!) : const SizedBox()),
                if (trailing != null) trailing!,
              ],
            ),
          if (title != null) ...[
            const SizedBox(height: 8),
            TwoToneTitle(title!),
          ],
          if (label != null || title != null) const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Marka renginde metin bağlantısı.
class LinkText extends StatelessWidget {
  const LinkText(this.text, {super.key, required this.onTap, this.color});
  final String text;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.dk.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Text(text, style: body(14, c, weight: FontWeight.w600)),
      ),
    );
  }
}

/// Ana eylem butonu: hap biçimli, mavi gradyan dolgulu (fizix).
class GradientButton extends StatelessWidget {
  const GradientButton(this.label, {super.key, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: DkColors.fill),
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20, color: Colors.white), const SizedBox(width: 10)],
                    Flexible(child: Text(label, style: body(16, Colors.white, weight: FontWeight.w600), textAlign: TextAlign.center)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hap biçimli küçük durum etiketi.
class Tag extends StatelessWidget {
  const Tag(this.text, this.color, {super.key});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(upper(text), style: small(10.5, color, spacing: 1.0, weight: FontWeight.w600)),
      );
}

/// Uygulamanın yazı işareti: ilk kelime düz, gerisi gradyan ("Acoustic Drone Detector").
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final i = kAppName.indexOf(' ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${kAppName.substring(0, i)} ', style: display(size, dk.ink)),
        GradientText(kAppName.substring(i + 1), style: display(size, dk.ink)),
      ],
    );
  }
}

String fmtDuration(Duration d) => S.current.duration(d);

String two(int v) => v.toString().padLeft(2, '0');

String fmtClock(DateTime t) => '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';

String fmtDate(DateTime t) => S.current.date(t);

String fmtThousands(num v) => S.current.thousands(v);
