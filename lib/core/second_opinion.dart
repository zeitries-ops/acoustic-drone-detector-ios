import 'dart:math' as math;
import 'dart:typed_data';

import 'yamnet_head.dart';

/// YAMNet gömmesinden (1024) drone olasılığı: p = sigmoid(w·e + b). Ölçekleyici ağırlıklara gömülü.
double yamnetHead(Float32List e) {
  var z = kYamnetBias;
  for (var i = 0; i < kYamnetW.length; i++) {
    z += kYamnetW[i] * e[i];
  }
  return 1 / (1 + math.exp(-z));
}

/// YAMNet'in ikinci görüşü: her ~0,48 sn'de bir drone olasılığı gelir.
///
/// Ortam öğrenme: dedektör ortamı öğrenirken gelen değerlerin ortalaması "ortam" sayılır; sonraki
/// değerlerin yalnızca ortamın üstünde kalan kısmı (yeniden ölçeklenmiş) kullanılır. Böylece dinleme
/// başlamadan önce açık olan bir fan ya da klima YAMNet tarafında sürekli drone oyu vermez, ama fan
/// çalışırken gelen drone yine fark edilir.
class SecondOpinion {
  double? _p;
  double _tUpdate = -1e9;
  final List<double> _amb = [];
  bool _learning = true;

  /// Ortamda öğrenilen YAMNet olasılığı.
  double ambient = 0;

  /// Son ham değer (ekranda göstermek ya da test için).
  double? get raw => _p;

  /// Bu kadar saniyedir yeni sonuç gelmediyse ikinci görüş yok sayılır.
  static const double staleAfter = 2.0;

  void update(double p, double t) {
    _p = p;
    _tUpdate = t;
    if (_learning) _amb.add(p);
  }

  void startLearning() {
    _learning = true;
    _amb.clear();
    ambient = 0;
    _p = null;
  }

  void finishLearning() {
    _learning = false;
    ambient = _amb.isEmpty ? 0 : _amb.reduce((a, b) => a + b) / _amb.length;
  }

  /// "Bu sesi yoksay": şu an duyulan da ortamın parçası.
  void absorbCurrent() {
    final p = _p;
    if (p != null && p > ambient) ambient = p;
  }

  /// Ortamı çıkarılmış olasılık; sonuç yoksa ya da eskidiyse null.
  double? value(double t) {
    final p = _p;
    if (p == null || t - _tUpdate > staleAfter) return null;
    if (!kYamnetRescaleAmbient) return p;
    // Ortamın üstünde kalan kısmı 0–1 aralığına yeniden ölçekle: ortam 0,6 ise 0,6 → 0, 1 → 1.
    final a = ambient.clamp(0.0, 0.95);
    return math.max(0.0, (p - a) / (1 - a));
  }

  /// İki görüşün birleşimi. YAMNet sonucu yoksa mevcut dedektörün değeri iki kez sayılır
  /// (birleşik eşikler bu durumda da tutarlı kalır).
  static double fuse(double ours, double? yam) => (ours + (yam ?? ours)) / 2;
}

/// Birleşik karar için alarm eşiği: hassasiyet 0,2 / 0,5 / 0,8 noktalarında ESC-50 yanlış alarmı
/// tek başına dedektörle aynı olacak şekilde seçildi (kYamnetFusedOn); arası doğrusal.
double fusedAlarmOn(double s) {
  const xs = [0.2, 0.5, 0.8];
  final ys = kYamnetFusedOn;
  double lin(double x0, double y0, double x1, double y1) => y0 + (s - x0) * (y1 - y0) / (x1 - x0);
  final v = s <= xs[1] ? lin(xs[0], ys[0], xs[1], ys[1]) : lin(xs[1], ys[1], xs[2], ys[2]);
  return v.clamp(0.3, 0.95);
}
