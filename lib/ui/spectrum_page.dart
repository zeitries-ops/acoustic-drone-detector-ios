import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/monitor.dart';
import '../app/spectrogram.dart';
import '../app/theme.dart';
import '../core/detector.dart';
import '../l10n/strings.dart';
import 'common.dart';

/// Spektrum sayfası: canlı spektrum ekranın kalanını doldurur, altında renk açıklaması. Kaydırılmaz.
/// Görüntü yalnızca bu sayfa açıkken üretilir.
class SpectrumPage extends StatefulWidget {
  const SpectrumPage({super.key, required this.monitor, this.trailing});
  final Monitor monitor;
  final Widget? trailing;

  @override
  State<SpectrumPage> createState() => _SpectrumPageState();
}

class _SpectrumPageState extends State<SpectrumPage> {
  @override
  void initState() {
    super.initState();
    widget.monitor.spectrogram.visible = true;
  }

  @override
  void dispose() {
    widget.monitor.spectrogram.visible = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monitor = widget.monitor;
    final t = S.of(context);
    return LayoutBuilder(builder: (context, c) {
      // yatay ekran ve iPad: açıklama spektrumun yanında; dikeyde altında, yüksekliği sınırlı
      final side = useTwoColumns(c.biggest);
      final view = SpectrogramView(monitor: monitor);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(t.spectrumTitle, trailing: widget.trailing),
          const SizedBox(height: 10),
          Expanded(
            child: side
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: view),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: (c.maxWidth * 0.28).clamp(170.0, 300.0),
                        child: const FitPage(child: _Legend(vertical: true)),
                      ),
                    ],
                  )
                : view,
          ),
          if (!side) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: c.maxHeight * 0.26),
              child: const FitPage(child: _Legend()),
            ),
          ],
        ],
      );
    });
  }
}

class _Legend extends StatelessWidget {
  const _Legend({this.vertical = false});
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    Color c(DetectorState s) {
      final v = SpectrogramBuffer.stateRgb(s);
      return Color.fromARGB(255, v[0], v[1], v[2]);
    }

    Widget item(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(text, style: small(12, dk.muted)),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          direction: vertical ? Axis.vertical : Axis.horizontal,
          spacing: vertical ? 8 : 14,
          runSpacing: 6,
          children: [
            item(c(DetectorState.calibrating), t.legendLearning),
            item(c(DetectorState.clear), t.legendClear),
            item(c(DetectorState.suspect), t.legendSuspect),
            item(c(DetectorState.drone), t.legendDrone),
          ],
        ),
        SizedBox(height: vertical ? 12 : 6),
        Text(t.legendText,
            style: body(12.5, dk.faint).copyWith(height: 1.35)),
      ],
    );
  }
}

/// Canlı spektrum: üstte durum şeridi, 0–4 kHz, son 24 sn; verilen alanı doldurur.
class SpectrogramView extends StatelessWidget {
  const SpectrogramView({super.key, required this.monitor});
  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    final m = monitor;
    final ms = small(11.5, dk.scopeInk);
    final rate = t.spectrumRate(rate: (m.sampleRate / 1000).toStringAsFixed(1));
    final info = m.listening ? '$rate${m.source.isNotEmpty ? ' · ${_sourceName(m.source, t)}' : ''}' : t.micOff;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: dk.scope,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 2,
                children: [
                  Text(t.spectrumRange, style: ms),
                  Text(info, style: ms),
                ],
              ),
            ),
            Expanded(
              // grafik yönü dilden bağımsız: zaman her zaman sağdan sola akar
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ValueListenableBuilder<ui.Image?>(
                      valueListenable: m.spectrogram.image,
                      builder: (context, img, _) => CustomPaint(painter: _ImagePainter(img)),
                    ),
                    LayoutBuilder(
                      builder: (context, box) => box.maxHeight < 90
                          ? const SizedBox.shrink()
                          : Stack(
                              children: [
                                for (final (i, label) in const ['4k', '3k', '2k', '1k'].indexed)
                                  Positioned(
                                    left: 6,
                                    top: 4 + box.maxHeight * i / 4,
                                    child: Text(label,
                                        textScaler: TextScaler.noScaling,
                                        style: ms.copyWith(fontSize: 10, shadows: [Shadow(color: dk.scope, blurRadius: 3)])),
                                  ),
                              ],
                            ),
                    ),
                    if (!m.listening)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            t.spectrumIdle(listen: t.tabListen),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: dk.scopeInk, fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _sourceName(String s, S t) {
    switch (s) {
      case 'android_unprocessed':
      case 'ios_measurement':
        return t.sourceRaw;
      case 'android_voice_recognition':
        return t.sourceLight;
      default:
        return t.sourceStandard;
    }
  }
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.image);
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(img, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(covariant _ImagePainter old) => old.image != image;
}
