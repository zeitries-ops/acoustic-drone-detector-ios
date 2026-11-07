import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drone_kulagi/core/detector.dart';
import 'package:drone_kulagi/core/second_opinion.dart';
import 'package:drone_kulagi/core/yamnet_head.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final golden = jsonDecode(File('test/data/yamnet_head_golden.json').readAsStringSync()) as Map<String, dynamic>;

  test('YAMNet başlığı Python ile aynı olasılığı verir', () {
    expect(kYamnetW.length, 1024);
    for (final g in golden['golden'] as List) {
      final e = Float32List.fromList([for (final v in g['e'] as List) (v as num).toDouble()]);
      expect(yamnetHead(e), closeTo((g['p'] as num).toDouble(), 1e-5));
    }
  });

  test('birleşik eşikler ölçüm noktalarından geçer ve hassasiyetle düşer', () {
    final ons = [for (final v in golden['fused_on'] as List) (v as num).toDouble()];
    expect(fusedAlarmOn(0.2), closeTo(ons[0], 1e-9));
    expect(fusedAlarmOn(0.5), closeTo(ons[1], 1e-9));
    expect(fusedAlarmOn(0.8), closeTo(ons[2], 1e-9));
    var prev = 2.0;
    for (var s = 0.0; s <= 1.0001; s += 0.05) {
      final v = fusedAlarmOn(s);
      expect(v, lessThanOrEqualTo(prev));
      expect(v, inInclusiveRange(0.3, 0.95));
      prev = v;
    }
  });

  test('ikinci görüş ortamı öğrenir, eskiyince devreden çıkar', () {
    final s = SecondOpinion();
    s.update(0.4, 1.0);
    s.update(0.6, 1.5);
    s.finishLearning();
    expect(s.ambient, closeTo(0.5, 1e-12));
    s.update(0.9, 4.0);
    expect(s.value(4.1), closeTo(kYamnetRescaleAmbient ? 0.8 : 0.9, 1e-12));
    expect(s.value(4.0 + SecondOpinion.staleAfter + 0.1), isNull);
    expect(SecondOpinion.fuse(0.8, null), 0.8);
    expect(SecondOpinion.fuse(0.8, 0.2), closeTo(0.5, 1e-12));
    s.startLearning();
    expect(s.ambient, 0);
    expect(s.value(5), isNull);
  });

  test('birleşim açılınca eşikler birleşik ölçeğe geçer', () {
    final d = DroneDetector(sensitivity: 0.5);
    expect(d.alarmOn, closeTo(0.70, 1e-9));
    d.setFusion(true);
    expect(d.alarmOn, closeTo(fusedAlarmOn(0.5), 1e-9));
    d.setSensitivity(0.8);
    expect(d.alarmOn, closeTo(fusedAlarmOn(0.8), 1e-9));
    d.setFusion(false);
    expect(d.alarmOn, closeTo(0.85 - 0.3 * 0.8, 1e-9));
  });
}
