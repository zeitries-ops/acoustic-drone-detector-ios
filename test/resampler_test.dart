import 'dart:math' as math;
import 'dart:typed_data';

import 'package:drone_kulagi/app/resampler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('48 kHz → 16 kHz: uzunluk ve frekans korunur', () {
    final rs = StreamResampler(48000, 16000);
    const f = 440.0;
    final out = <double>[];
    for (var block = 0; block < 10; block++) {
      final x = Float32List(4800);
      for (var i = 0; i < x.length; i++) {
        final n = block * 4800 + i;
        x[i] = math.sin(2 * math.pi * f * n / 48000);
      }
      out.addAll(rs.process(x));
    }
    expect(out.length, closeTo(16000, 3));
    // sıfırdan geçişlerden frekans
    var crossings = 0;
    for (var i = 2001; i < out.length; i++) {
      if (out[i - 1] < 0 && out[i] >= 0) crossings++;
    }
    final seconds = (out.length - 2001) / 16000;
    expect(crossings / seconds, closeTo(f, 3));
  });

  test('aynı hızda veri değişmeden geçer', () {
    final rs = StreamResampler(16000, 16000);
    final x = Float32List.fromList([0.1, 0.2, 0.3]);
    expect(rs.process(x), same(x));
  });
}
