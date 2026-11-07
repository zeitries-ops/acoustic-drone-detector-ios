import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drone_kulagi/core/detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dart dedektörü, başvuru JS uygulamasıyla (research/algo/detector2.js) aynı sonucu vermeli.
/// Test sesi kendi ürettiğimiz sentetik bir kayıttır: ortam → drone (5–14 sn) → fan (15. sn'den sonra).
Float32List readWav(String path) {
  final b = File(path).readAsBytesSync();
  final bd = ByteData.sublistView(b);
  var p = 12;
  while (p < b.length) {
    final id = String.fromCharCodes(b.sublist(p, p + 4));
    final sz = bd.getUint32(p + 4, Endian.little);
    if (id == 'data') {
      final n = sz ~/ 2;
      final x = Float32List(n);
      for (var i = 0; i < n; i++) {
        x[i] = bd.getInt16(p + 8 + i * 2, Endian.little) / 32768;
      }
      return x;
    }
    p += 8 + sz + (sz & 1);
  }
  throw StateError('data bölümü yok');
}

const _names = {
  DetectorState.calibrating: 'calibrating',
  DetectorState.clear: 'clear',
  DetectorState.suspect: 'suspect',
  DetectorState.drone: 'drone',
};

void main() {
  test('Dart dedektörü JS başvurusuyla aynı kararları verir', () {
    final x = readWav('test/golden/synthetic_16k.wav');
    final expected = (jsonDecode(File('test/golden/expected.json').readAsStringSync())['frames'] as List).cast<Map>();
    final det = DroneDetector(sampleRate: 16000, fftSize: 4096);
    var same = 0, total = 0;
    var maxConfDiff = 0.0;
    var i = 0;
    for (var e = 4096; e <= x.length; e += 1600, i++) {
      final r = det.process(Float32List.sublistView(x, e - 4096, e), (i + 1) * 0.1);
      final exp = expected[i];
      total++;
      if (_names[r.state] == exp['s']) same++;
      final d = (r.conf - (exp['c'] as num).toDouble()).abs();
      if (d > maxConfDiff) maxConfDiff = d;
    }
    expect(total, expected.length);
    expect(same / total, greaterThanOrEqualTo(0.98), reason: 'durum uyumu $same/$total');
    expect(maxConfDiff, lessThan(1e-2), reason: 'en büyük güven farkı $maxConfDiff');
  });

  test('drone bölümünde alarm verir, fan bölümünde vermez', () {
    final x = readWav('test/golden/synthetic_16k.wav');
    final det = DroneDetector(sampleRate: 16000, fftSize: 4096);
    final states = <double, DetectorState>{};
    var i = 0;
    for (var e = 4096; e <= x.length; e += 1600, i++) {
      final t = e / 16000;
      states[t] = det.process(Float32List.sublistView(x, e - 4096, e), t).state;
    }
    final droneSpan = states.entries.where((s) => s.key > 8 && s.key < 14);
    final fanSpan = states.entries.where((s) => s.key > 18);
    expect(droneSpan.any((s) => s.value == DetectorState.drone), isTrue);
    expect(fanSpan.every((s) => s.value != DetectorState.drone), isTrue);
  });

  test('hassasiyet eşikleri doğru aralıkta', () {
    final det = DroneDetector();
    det.setSensitivity(0);
    expect(det.alarmOn, closeTo(0.85, 1e-9));
    det.setSensitivity(1);
    expect(det.alarmOn, closeTo(0.55, 1e-9));
    expect(det.suspectOn, lessThan(det.alarmOn));
  });
}
