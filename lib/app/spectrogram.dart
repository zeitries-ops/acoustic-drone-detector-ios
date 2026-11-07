import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/detector.dart';

/// Kayan spektrogram: en yeni sütun sağda. 0–4 kHz, üstte durum şeridi, sağda harmonik rayı.
class SpectrogramBuffer {
  SpectrogramBuffer({this.cols = 240, this.rows = 160}) : _px = Uint8List(cols * (rows + strip) * 4) {
    clear();
  }

  static const int strip = 6;
  static const int rail = 5;
  static const double fMax = 4000;

  final int cols;
  final int rows;
  final Uint8List _px;
  final ValueNotifier<ui.Image?> image = ValueNotifier<ui.Image?>(null);
  bool _decoding = false;
  bool _dirty = false;
  bool _visible = false;

  /// Spektrum sayfası açıkken görüntü üretilir; kapalıyken yalnızca piksel tamponu güncellenir (pil, GPU).
  bool get visible => _visible;
  set visible(bool v) {
    if (v == _visible) return;
    _visible = v;
    if (v) _publish();
  }

  int get height => rows + strip;

  static final List<int> _lut = _buildLut();

  static List<int> _buildLut() {
    const stopT = [0.0, 0.22, 0.48, 0.72, 1.0];
    const stopC = [
      [9, 13, 18],
      [22, 34, 72],
      [46, 86, 214],
      [236, 160, 52],
      [255, 246, 224],
    ];
    final lut = List<int>.filled(256 * 3, 0);
    for (var i = 0; i < 256; i++) {
      final t = i / 255;
      var j = 0;
      while (j < stopT.length - 2 && t > stopT[j + 1]) {
        j++;
      }
      final u = (t - stopT[j]) / (stopT[j + 1] - stopT[j]);
      for (var c = 0; c < 3; c++) {
        lut[i * 3 + c] = (stopC[j][c] + (stopC[j + 1][c] - stopC[j][c]) * u).round();
      }
    }
    return lut;
  }

  static const _bg = [9, 13, 18];

  static List<int> stateRgb(DetectorState s) {
    switch (s) {
      case DetectorState.calibrating:
        return const [70, 100, 220];
      case DetectorState.clear:
        return const [40, 160, 110];
      case DetectorState.suspect:
        return const [240, 170, 50];
      case DetectorState.drone:
        return const [255, 90, 80];
    }
  }

  void clear() {
    for (var i = 0; i < _px.length; i += 4) {
      _px[i] = _bg[0];
      _px[i + 1] = _bg[1];
      _px[i + 2] = _bg[2];
      _px[i + 3] = 255;
    }
    _publish();
  }

  void _set(int x, int y, List<int> c) {
    final o = (y * cols + x) * 4;
    _px[o] = c[0];
    _px[o + 1] = c[1];
    _px[o + 2] = c[2];
    _px[o + 3] = 255;
  }

  /// Dedektörün yumuşatılmış spektrumundan yeni bir sütun ekler.
  void push(Float64List dB, double binHz, DetectorState state, List<Harmonic>? harm) {
    final area = cols - rail;
    final h = height;
    // bir sütun sola kaydır
    for (var y = 0; y < h; y++) {
      final row = y * cols * 4;
      _px.setRange(row, row + (area - 1) * 4, _px, row + 4);
    }
    // referans: 100–4000 Hz bandının medyanı
    final k0 = (100 / binHz).round().clamp(1, dB.length - 1);
    final k1 = (fMax / binHz).round().clamp(k0, dB.length - 1);
    final sample = <double>[];
    for (var k = k0; k <= k1; k += 3) {
      sample.add(dB[k]);
    }
    sample.sort();
    final ref = sample[sample.length >> 1];
    final per = (fMax / binHz) / rows;
    final x = area - 1;
    final sc = stateRgb(state);
    for (var y = 0; y < strip; y++) {
      _set(x, y, sc);
    }
    for (var r = 0; r < rows; r++) {
      // r = 0 en üstteki satır (4 kHz)
      final fr = rows - 1 - r;
      final ka = (fr * per).floor().clamp(1, dB.length - 1);
      final kb = ((fr + 1) * per).ceil().clamp(ka, dB.length - 1);
      var m = -300.0;
      for (var k = ka; k <= kb; k++) {
        if (dB[k] > m) m = dB[k];
      }
      final v = (m - ref + 2) / 38;
      final li = v <= 0 ? 0 : (v >= 1 ? 255 : (v * 255).floor());
      _set(x, strip + r, [_lut[li * 3], _lut[li * 3 + 1], _lut[li * 3 + 2]]);
    }
    // harmonik rayı
    for (var y = 0; y < h; y++) {
      for (var xx = area; xx < cols; xx++) {
        _set(xx, y, _bg);
      }
    }
    if (harm != null && (state == DetectorState.suspect || state == DetectorState.drone)) {
      final mc = state == DetectorState.drone ? const [255, 106, 96] : const [240, 174, 58];
      for (final hm in harm) {
        if (hm.evidence < 6 || hm.freq > fMax) continue;
        final yy = strip + ((1 - hm.freq / fMax) * rows).floor();
        for (var dy = 0; dy < 2; dy++) {
          final row = (yy + dy).clamp(strip, h - 1);
          for (var xx = area + 1; xx < cols; xx++) {
            _set(xx, row, mc);
          }
        }
      }
    }
    _publish();
  }

  void _publish() {
    if (!_visible) return;
    if (_decoding) {
      _dirty = true;
      return;
    }
    _decoding = true;
    final copy = Uint8List.fromList(_px);
    ui.decodeImageFromPixels(copy, cols, height, ui.PixelFormat.rgba8888, (img) {
      final old = image.value;
      image.value = img;
      old?.dispose();
      _decoding = false;
      if (_dirty) {
        _dirty = false;
        scheduleMicrotask(_publish);
      }
    });
  }

  void dispose() {
    image.value?.dispose();
    image.dispose();
  }
}
