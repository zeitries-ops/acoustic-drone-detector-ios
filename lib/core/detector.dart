// Drone Kulağı v2 – akustik drone tespit çekirdeği (Dart).
//
// research/algo/detector2.js ile birebir aynı mantık; test/detector_golden_test.dart
// iki uygulamanın aynı sonucu verdiğini doğrular.
//
// Aşama A: tonallık T, ortam profili A, kanıt E = T − A, harmonik seri araması.
// Aşama B: hassas temel frekans, harmonik tutarsızlığı (çoklu rotor), küme genişliği,
//          alt tepe sayısı, şebeke (50/60 Hz) kilidi, harmonik/gürültü oranı.
// Aşama C: 2,4 sn pencere → lojistik regresyon → olasılık → üstel ortalama → durum.

import 'dart:math' as math;
import 'dart:typed_data';

import 'model.dart';
import 'second_opinion.dart';

enum DetectorState { calibrating, clear, suspect, drone }

enum DronePreset { multi, fpv, wide }

class PresetRange {
  const PresetRange(this.fMin, this.fMax);
  final double fMin;
  final double fMax;
}

const Map<DronePreset, PresetRange> kPresets = {
  DronePreset.multi: PresetRange(90, 450),
  DronePreset.fpv: PresetRange(180, 900),
  DronePreset.wide: PresetRange(70, 900),
};

int jsRound(double x) => (x + 0.5).floor();

double _median(List<double> a) {
  if (a.isEmpty) return double.nan;
  final s = List<double>.of(a)..sort();
  return s[s.length >> 1];
}

double _weightedMedian(List<double> vals, List<double> ws) {
  final idx = List<int>.generate(vals.length, (i) => i)..sort((a, b) => vals[a].compareTo(vals[b]));
  var tot = 0.0;
  for (final w in ws) {
    tot += w;
  }
  var acc = 0.0;
  for (final i in idx) {
    acc += ws[i];
    if (acc >= tot / 2) return vals[i];
  }
  return vals[idx.last];
}

double _log10(double x) => math.log(x) / math.ln10;

class Fft {
  Fft(this.n)
      : rev = Uint32List(n),
        cosT = Float64List(n ~/ 2),
        sinT = Float64List(n ~/ 2) {
    final levels = (math.log(n) / math.ln2).round();
    for (var i = 0; i < n; i++) {
      var r = 0, x = i;
      for (var b = 0; b < levels; b++) {
        r = (r << 1) | (x & 1);
        x >>= 1;
      }
      rev[i] = r;
    }
    for (var k = 0; k < n ~/ 2; k++) {
      cosT[k] = math.cos(2 * math.pi * k / n);
      sinT[k] = -math.sin(2 * math.pi * k / n);
    }
  }

  final int n;
  final Uint32List rev;
  final Float64List cosT;
  final Float64List sinT;

  void transform(Float64List re, Float64List im) {
    for (var i = 0; i < n; i++) {
      final j = rev[i];
      if (j > i) {
        var t = re[i];
        re[i] = re[j];
        re[j] = t;
        t = im[i];
        im[i] = im[j];
        im[j] = t;
      }
    }
    for (var size = 2; size <= n; size <<= 1) {
      final half = size >> 1, step = n ~/ size;
      for (var start = 0; start < n; start += size) {
        for (var k = 0; k < half; k++) {
          final wr = cosT[k * step], wi = sinT[k * step];
          final a = start + k, b = a + half;
          final xr = re[b] * wr - im[b] * wi;
          final xi = re[b] * wi + im[b] * wr;
          re[b] = re[a] - xr;
          im[b] = im[a] - xi;
          re[a] += xr;
          im[a] += xi;
        }
      }
    }
  }
}

class Harmonic {
  const Harmonic(this.freq, this.evidence);
  final double freq;
  final double evidence;
}

/// Tek karede bulunan adayın analizi.
class FrameAnalysis {
  FrameAnalysis(this.harm, this.hE, this.nGood);
  final List<Harmonic> harm;
  final double hE;
  final int nGood;
  double f0p = 0;
  double inharm = double.nan;
  double widthRel = double.nan;
  double subPk = double.nan;
  double mains = double.nan;
  double hnr = double.nan;
  double strength = 0;
  double score = 0;
  int hits = 0;
  int h = 0;
}

/// 2,4 sn pencerenin özeti; lojistik regresyonun girdileri.
class Aggregate {
  int nDet = 0;
  double cont = 0, stab = 0, v1conf = 0, medF0 = 0;
  double flux = 0, jumpFrac = 0;
  double jitter = double.nan, inharm = double.nan, widthRel = double.nan, subPk = double.nan;
  double mains = double.nan, hitsRatio = double.nan, hnr = double.nan, nHarm = double.nan;
  double f0p = 0;
  bool steady = false;

  double feature(String name) {
    switch (name) {
      case 'cont':
        return cont;
      case 'stab':
        return stab;
      case 'v1conf':
        return v1conf;
      case 'flux':
        return flux;
      case 'jitter':
        return jitter;
      case 'inharm':
        return inharm;
      case 'widthRel':
        return widthRel;
      case 'subPk':
        return subPk;
      case 'mains':
        return mains;
      case 'hitsRatio':
        return hitsRatio;
      case 'hnr':
        return hnr;
      case 'nHarm':
        return nHarm;
    }
    return double.nan;
  }
}

/// Arayüzde gösterilen gerekçeler; null = bu ipucu için yeterli veri yok.
class Reasons {
  const Reasons({this.multiRotor, this.rpmJitter, this.mainsLock, required this.levelSteady});
  final bool? multiRotor;
  final bool? rpmJitter;
  final bool? mainsLock;
  final bool levelSteady;
}

/// "Bu ses benim cihazım" imzası.
class IgnoredSignature {
  const IgnoredSignature({required this.f0, required this.mains, required this.jitter, required this.createdMs});
  final double f0;
  final double mains;
  final double jitter;
  final int createdMs;

  Map<String, Object> toJson() => {'f0': f0, 'mains': mains, 'jitter': jitter.isFinite ? jitter : -1, 'created': createdMs};

  static IgnoredSignature? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final f0 = (raw['f0'] as num?)?.toDouble() ?? 0.0;
    if (f0 <= 0) return null;
    final j = (raw['jitter'] as num?)?.toDouble() ?? -1;
    return IgnoredSignature(
      f0: f0,
      mains: (raw['mains'] as num?)?.toDouble() ?? 0,
      jitter: j < 0 ? double.nan : j,
      createdMs: (raw['created'] as num?)?.toInt() ?? 0,
    );
  }
}

class DetectorResult {
  DetectorResult({
    required this.t,
    required this.state,
    required this.calibrating,
    required this.calibProgress,
    required this.conf,
    required this.p,
    required this.levelDb,
    required this.trend,
    this.fr,
    this.agg,
    this.reasons,
    this.f0 = 0,
    this.det = false,
    this.ignoredHit = false,
    this.veto = false,
  });

  final double t;
  final DetectorState state;
  final bool calibrating;
  final double calibProgress;
  final double conf;
  final double p;
  final double levelDb;
  final double trend;
  final FrameAnalysis? fr;
  final Aggregate? agg;
  final Reasons? reasons;
  final double f0;
  final bool det;
  final bool ignoredHit;

  /// Cihaz kuralı (şebeke kilidi / tamamen sabit ses) olasılığı bastırdı.
  final bool veto;
}

class _HistRow {
  _HistRow(this.det, this.f0, this.f0p, this.hE, this.inharm, this.widthRel, this.subPk, this.mains, this.hitsRatio,
      this.hnr, this.nHarm);
  final bool det;
  final double f0, f0p, hE, inharm, widthRel, subPk, mains, hitsRatio, hnr, nHarm;

  double get(String key) {
    switch (key) {
      case 'inharm':
        return inharm;
      case 'widthRel':
        return widthRel;
      case 'subPk':
        return subPk;
      case 'mains':
        return mains;
      case 'hitsRatio':
        return hitsRatio;
      case 'hnr':
        return hnr;
      case 'nHarm':
        return nHarm;
    }
    return double.nan;
  }
}

class _Good {
  _Good(this.h, this.fh, this.em, this.width, this.sub, this.pw, this.clean);
  final int h;
  final double fh, em, width;
  final int sub;
  final double pw;
  final bool clean;
}

class DroneDetector {
  DroneDetector({
    int sampleRate = 16000,
    int? fftSize,
    DronePreset preset = DronePreset.multi,
    double sensitivity = 0.5,
    this.calibFrames = 30,
    this.histLen = 24,
    DetectorModel? model,
  })  : sr = sampleRate,
        n = fftSize ?? (sampleRate > 30000 ? 8192 : 4096),
        model = model ?? kDefaultModel {
    nb = n >> 1;
    binHz = sr / n;
    _fft = Fft(n);
    _win = Float64List(n);
    var wsum = 0.0;
    for (var i = 0; i < n; i++) {
      _win[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
      wsum += _win[i];
    }
    _norm = 1 / (wsum * wsum);
    _re = Float64List(n);
    _im = Float64List(n);
    _pi = Float64List(nb);
    _ps = Float64List(nb);
    dB = Float64List(nb);
    _dBi = Float64List(nb);
    _t = Float64List(nb);
    _a = Float64List(nb);
    _aSum = Float64List(nb);
    _e = Float64List(nb);
    _prefix = Float64List(nb + 1);
    _localOuter = math.max(6, jsRound(70 / binHz));
    _localInner = math.max(3, jsRound(16 / binHz));
    _bandLo = math.max(1, (60 / binHz).floor());
    _bandHi = math.min(nb - 1, (5200 / binHz).ceil());
    _hnrLo = math.max(1, (100 / binHz).floor());
    _hnrHi = math.min(nb - 1, (4000 / binHz).ceil());
    setPreset(preset);
    setSensitivity(sensitivity);
    reset();
  }

  final int sr;
  final int n;
  final int calibFrames;
  final int histLen;
  DetectorModel model;

  late final int nb;
  late final double binHz;
  late final Fft _fft;
  late final Float64List _win;
  late final double _norm;
  late final Float64List _re, _im, _pi, _ps, _dBi, _t, _a, _aSum, _e, _prefix;

  /// Yumuşatılmış spektrum (dB) – spektrum ekranı bunu çizer.
  late final Float64List dB;

  static const double fTop = 4000;
  static const int maxHarm = 14;
  static const double hitDb = 6;
  static const double smoothBeta = 0.35;
  static const double mainsTolHz = 0.6;
  late final int _localOuter, _localInner, _bandLo, _bandHi, _hnrLo, _hnrHi;

  DronePreset preset = DronePreset.multi;
  double sensitivity = 0.5;
  static const int _minHits = 4;
  static const double _scoreThr = 7;
  static const double alpha = 0.15;
  static const int hold = 10;
  int _run = 0;
  double alarmOn = 0.7, alarmOff = 0.5, suspectOn = 0.43;

  /// YAMNet ikinci görüşü. [fused] açıkken karar olasılığı iki görüşün ortalamasıdır.
  final SecondOpinion second = SecondOpinion();
  bool fused = false;

  late Float64List _cands;
  late Int32List _cOff, _cLo, _cHi;

  int _frame = 0;
  int _calibCount = 0;
  bool _calibrating = true;
  final List<_HistRow> _hist = [];
  final List<double> _strengthHist = [];
  double _conf = 0;
  DetectorState state = DetectorState.calibrating;
  Aggregate? lastAgg;
  List<IgnoredSignature> _ignored = [];

  void setPreset(DronePreset p) {
    preset = p;
    final r = kPresets[p]!;
    final cands = <double>[];
    final offs = <int>[0];
    final los = <int>[];
    final his = <int>[];
    for (var f0 = r.fMin; f0 <= r.fMax; f0 *= 1.005) {
      final hCount = math.min(maxHarm, (fTop / f0).floor());
      if (hCount < 3) continue;
      for (var h = 1; h <= hCount; h++) {
        final c = h * f0 / binHz;
        final tol = math.max(1.0, 0.01 * c);
        los.add(math.max(_bandLo, jsRound(c - tol)));
        his.add(math.min(_bandHi, jsRound(c + tol)));
      }
      cands.add(f0);
      offs.add(los.length);
    }
    _cands = Float64List.fromList(cands);
    _cOff = Int32List.fromList(offs);
    _cLo = Int32List.fromList(los);
    _cHi = Int32List.fromList(his);
  }

  /// Hassasiyet yalnızca karar eşiklerini kaydırır; aday bulucu sabit kalır
  /// (model bu ayarla üretilen özelliklerle eğitildi).
  void setSensitivity(double s) {
    s = s.clamp(0.0, 1.0);
    sensitivity = s;
    alarmOn = fused ? fusedAlarmOn(s) : 0.85 - 0.3 * s;
    alarmOff = alarmOn - 0.2;
    suspectOn = alarmOn - 0.25;
  }

  /// YAMNet hazırsa birleşik karara geç (eşikler de birleşik ölçeğe göre ayarlanır).
  void setFusion(bool on) {
    fused = on;
    setSensitivity(sensitivity);
  }

  /// Fizik tabanlı cihaz kuralı: şebekeye kilitli ya da tamamen sabit, tek çizgili ses.
  /// Açık veri setlerindeki gerçek drone karelerinin hiçbirinde tetiklenmedi.
  static bool deviceVeto(Aggregate a) {
    final j = a.jitter;
    final fan = a.mains >= 0.6 && j < 0.0015;
    final steady = j < 0.0012 && a.flux < 0.5 && a.subPk <= 1.5;
    return fan || steady;
  }

  void reset() {
    _frame = 0;
    _ps.fillRange(0, nb, 0);
    _a.fillRange(0, nb, 0);
    _aSum.fillRange(0, nb, 0);
    _calibCount = 0;
    _calibrating = true;
    _hist.clear();
    _strengthHist.clear();
    _conf = 0;
    _run = 0;
    state = DetectorState.calibrating;
    second.startLearning();
  }

  void recalibrate() {
    _a.fillRange(0, nb, 0);
    _aSum.fillRange(0, nb, 0);
    _calibCount = 0;
    _calibrating = true;
    _hist.clear();
    _conf = 0;
    _run = 0;
    state = DetectorState.calibrating;
    second.startLearning();
  }

  /// Şu anki tonal sesleri ortamın parçası say; imza verilirse yoksayma listesine ekle.
  void learnAmbient([IgnoredSignature? sig]) {
    for (var k = _bandLo; k <= _bandHi; k++) {
      final w = math.max(2, jsRound(0.02 * k));
      var mx = -1e9;
      final j0 = math.max(_bandLo, k - w), j1 = math.min(_bandHi, k + w);
      for (var j = j0; j <= j1; j++) {
        if (_t[j] > mx) mx = _t[j];
      }
      final v = mx + 2;
      if (v > _a[k]) _a[k] = v;
    }
    if (sig != null && sig.f0 > 0) _ignored = [..._ignored, sig];
    second.absorbCurrent();
    _hist.clear();
    _conf = 0;
    state = DetectorState.clear;
  }

  void setIgnored(List<IgnoredSignature> list) => _ignored = list.where((s) => s.f0 > 0).toList();

  IgnoredSignature? signature() {
    final a = lastAgg;
    if (a == null || !(a.f0p > 0)) return null;
    return IgnoredSignature(
        f0: a.f0p, mains: a.mains.isFinite ? a.mains : 0, jitter: a.jitter, createdMs: DateTime.now().millisecondsSinceEpoch);
  }

  bool _matchesIgnored(double f0p, double jitter, double mains) {
    for (final s in _ignored) {
      for (final r in const [1.0, 2.0, 0.5]) {
        final q = f0p / (s.f0 * r);
        if (q > 0.98 && q < 1.02) {
          if ((jitter.isFinite && jitter < 0.004) || (mains.isFinite && mains > 0.5)) return true;
        }
      }
    }
    return false;
  }

  DetectorResult process(Float32List frame, double t) {
    _frame++;
    var ss = 0.0;
    for (var i = 0; i < n; i++) {
      ss += frame[i] * frame[i];
    }
    final levelDb = 20 * _log10(math.sqrt(ss / n) + 1e-9);

    for (var i = 0; i < n; i++) {
      _re[i] = frame[i] * _win[i];
      _im[i] = 0;
    }
    _fft.transform(_re, _im);
    final beta = _frame == 1 ? 1.0 : smoothBeta;
    for (var k = 0; k < nb; k++) {
      final p = (_re[k] * _re[k] + _im[k] * _im[k]) * _norm * 4;
      _pi[k] = p;
      _ps[k] += beta * (p - _ps[k]);
      dB[k] = 10 * _log10(_ps[k] + 1e-16);
      _dBi[k] = 10 * _log10(p + 1e-16);
    }

    final pre = _prefix;
    pre[0] = 0;
    for (var k = 0; k < nb; k++) {
      pre[k + 1] = pre[k] + dB[k];
    }
    for (var k = _bandLo; k <= _bandHi; k++) {
      final a0 = math.max(0, k - _localOuter), a1 = math.min(nb - 1, k + _localOuter);
      final b0 = math.max(0, k - _localInner), b1 = math.min(nb - 1, k + _localInner);
      final cnt = (a1 - a0 + 1) - (b1 - b0 + 1);
      _t[k] = dB[k] - ((pre[a1 + 1] - pre[a0]) - (pre[b1 + 1] - pre[b0])) / cnt;
    }

    if (_calibrating) {
      for (var k = _bandLo; k <= _bandHi; k++) {
        _aSum[k] += _t[k];
      }
      _calibCount++;
      if (_calibCount >= calibFrames) {
        for (var k = _bandLo; k <= _bandHi; k++) {
          _a[k] = math.max(0, _aSum[k] / _calibCount + 1);
        }
        _calibrating = false;
        state = DetectorState.clear;
        second.finishLearning();
      }
      return _result(t, levelDb, null, null, 0);
    }

    for (var k = _bandLo; k <= _bandHi; k++) {
      final e = _t[k] - _a[k];
      _e[k] = e < 0 ? 0 : (e > 20 ? 20 : e);
    }

    // Aşama A
    var best = -1, bestHits = 0, bestH = 0;
    var bestScore = 0.0;
    for (var c = 0; c < _cands.length; c++) {
      var s = 0.0;
      var hits = 0;
      final o0 = _cOff[c], o1 = _cOff[c + 1];
      for (var o = o0; o < o1; o++) {
        var m = 0.0;
        final hi = _cHi[o];
        for (var k = _cLo[o]; k <= hi; k++) {
          if (_e[k] > m) m = _e[k];
        }
        s += m;
        if (m >= hitDb) hits++;
      }
      final hCount = o1 - o0;
      final score = s / math.sqrt(hCount);
      if (score > bestScore) {
        bestScore = score;
        best = c;
        bestHits = hits;
        bestH = hCount;
      }
    }
    final f0 = best >= 0 ? _cands[best] : 0.0;
    final det = best >= 0 && bestHits >= _minHits && bestScore >= _scoreThr;

    // Aşama B
    final fr = best >= 0 ? _analyze(best, f0) : null;
    if (fr != null) {
      fr.score = bestScore;
      fr.hits = bestHits;
      fr.h = bestH;
    }

    // Aşama C
    _hist.add(_HistRow(
      det,
      det ? f0 : 0,
      det && fr != null ? fr.f0p : 0,
      det && fr != null ? fr.hE : 0,
      fr?.inharm ?? double.nan,
      fr?.widthRel ?? double.nan,
      fr?.subPk ?? double.nan,
      fr?.mains ?? double.nan,
      fr != null ? bestHits / bestH : 0,
      fr?.hnr ?? double.nan,
      fr != null ? fr.nGood.toDouble() : 0,
    ));
    if (_hist.length > histLen) _hist.removeAt(0);
    final agg = _aggregate();

    var ignoredHit = false;
    if (agg.nDet >= 3 && _ignored.isNotEmpty && _matchesIgnored(agg.f0p, agg.jitter, agg.mains)) {
      ignoredHit = true;
    }
    var p = 0.0;
    var veto = false;
    if (agg.nDet >= 3 && !ignoredHit) {
      p = model.predict(agg);
      veto = deviceVeto(agg);
      if (veto) p = math.min(p, 0.1);
    }
    // Karar olasılığı: YAMNet hazırsa iki görüşün ortalaması; yoksayılan cihaz sesinde sıfır.
    final pd = !fused ? p : (ignoredHit ? 0.0 : SecondOpinion.fuse(p, second.value(t)));
    _conf += alpha * (pd - _conf);
    _run = _conf >= alarmOn ? _run + 1 : 0;

    final strength = fr?.strength ?? 0.0;
    _strengthHist.add(det ? strength : 0);
    if (_strengthHist.length > 30) _strengthHist.removeAt(0);

    final prev = state;
    if (prev == DetectorState.drone) {
      if (_conf < alarmOff) state = _conf >= suspectOn ? DetectorState.suspect : DetectorState.clear;
    } else if (_run > hold) {
      state = DetectorState.drone;
    } else if (_conf >= suspectOn) {
      state = DetectorState.suspect;
    } else {
      state = DetectorState.clear;
    }

    if (state == DetectorState.clear) {
      for (var k = _bandLo; k <= _bandHi; k++) {
        final d = _t[k] - _a[k];
        _a[k] += d > 0 ? 0.002 * d : 0.01 * d;
        if (_a[k] < 0) _a[k] = 0;
      }
    }

    lastAgg = agg;
    return _result(t, levelDb, fr, agg, p, f0: f0, det: det, ignoredHit: ignoredHit, veto: veto);
  }

  FrameAnalysis _analyze(int best, double f0) {
    final good = <_Good>[];
    final harm = <Harmonic>[];
    var he = 0.0;
    var h = 1;
    for (var o = _cOff[best]; o < _cOff[best + 1]; o++, h++) {
      var em = 0.0, pm = 0.0;
      for (var k = _cLo[o]; k <= _cHi[o]; k++) {
        if (_e[k] > em) em = _e[k];
        if (_pi[k] > pm) pm = _pi[k];
      }
      he += pm;
      harm.add(Harmonic(h * f0, em));
      if (em < hitDb) continue;
      final c = h * f0 / binHz;
      final wb = math.max(3.0, math.min(0.05 * c, 0.45 * f0 / binHz));
      final k0 = math.max(_bandLo, (c - wb).floor()), k1 = math.min(_bandHi, (c + wb).ceil());
      var kp = k0;
      for (var k = k0; k <= k1; k++) {
        if (_dBi[k] > _dBi[kp]) kp = k;
      }
      var delta = 0.0;
      if (kp > k0 && kp < k1) {
        final a = _dBi[kp - 1], b = _dBi[kp], cc = _dBi[kp + 1];
        final den = a - 2 * b + cc;
        if (den < 0) delta = (0.5 * (a - cc) / den).clamp(-0.5, 0.5);
      }
      final fh = (kp + delta) * binHz;
      var ks = k0;
      for (var k = k0; k <= k1; k++) {
        if (dB[k] > dB[ks]) ks = k;
      }
      final pk = dB[ks];
      final fl = pk - _t[ks];
      final clean = pk - fl >= 10;
      final wThr = math.max(pk - 10, fl + 4);
      var wcount = 0;
      for (var k = k0; k <= k1; k++) {
        if (dB[k] >= wThr) wcount++;
      }
      final sThr = math.max(pk - 8, fl + 4);
      var sub = 0, lastK = -10;
      for (var k = k0 + 1; k < k1; k++) {
        if (dB[k] >= dB[k - 1] && dB[k] > dB[k + 1] && dB[k] >= sThr && k - lastK >= 2) {
          sub++;
          lastK = k;
        }
      }
      if (sub == 0) sub = 1;
      final pw = _pi[math.max(0, kp - 1)] + _pi[kp] + _pi[math.min(nb - 1, kp + 1)];
      good.add(_Good(h, fh, em, wcount * binHz, sub, pw, clean));
    }
    final fr = FrameAnalysis(harm, 10 * _log10(he + 1e-16), good.length);
    if (good.isEmpty) return fr;

    var sh = 0.0;
    for (final g in good) {
      sh += g.em;
    }
    fr.strength = sh / good.length;

    final vals = [for (final g in good) g.fh / g.h];
    final ws = [for (final g in good) g.h * g.em];
    final f0p = _weightedMedian(vals, ws);
    fr.f0p = f0p;

    if (good.length >= 2) {
      var sw = 0.0, sv = 0.0;
      for (var i = 0; i < good.length; i++) {
        final d = math.log(good[i].fh / (good[i].h * f0p));
        sw += ws[i];
        sv += ws[i] * d * d;
      }
      fr.inharm = math.sqrt(sv / sw);
    }
    final cl = good.where((g) => g.clean).toList();
    if (cl.length >= 3) {
      var mx = 0.0, my = 0.0;
      for (final g in cl) {
        mx += g.h * f0;
        my += g.width;
      }
      mx /= cl.length;
      my /= cl.length;
      var sxy = 0.0, sxx = 0.0;
      for (final g in cl) {
        final dx = g.h * f0 - mx;
        sxy += dx * (g.width - my);
        sxx += dx * dx;
      }
      fr.widthRel = sxx > 0 ? sxy / sxx : double.nan;
    }
    final hiH = good.where((g) => g.h >= 3).toList();
    final subSrc = hiH.isNotEmpty ? hiH : good;
    fr.subPk = subSrc.fold<double>(0, (a, g) => a + g.sub) / subSrc.length;

    var m50 = 0, m60 = 0;
    for (final g in good) {
      if ((g.fh - 50 * jsRound(g.fh / 50)).abs() < mainsTolHz) m50++;
      if ((g.fh - 60 * jsRound(g.fh / 60)).abs() < mainsTolHz) m60++;
    }
    fr.mains = math.max(m50, m60) / good.length;

    var ph = 0.0, pb = 0.0;
    for (final g in good) {
      ph += g.pw;
    }
    for (var k = _hnrLo; k <= _hnrHi; k++) {
      pb += _pi[k];
    }
    fr.hnr = 10 * _log10((ph + 1e-16) / (pb + 1e-16));
    return fr;
  }

  Aggregate _aggregate() {
    final a = Aggregate();
    final hist = _hist;
    final f0s = <double>[];
    for (final x in hist) {
      if (x.det) {
        a.nDet++;
        f0s.add(x.f0);
      }
    }
    a.cont = a.nDet / histLen;
    if (f0s.length >= 3) {
      a.medF0 = _median(f0s);
      var ok = 0;
      for (final f in f0s) {
        final r = f / a.medF0;
        if ((r > 0.88 && r < 1.12) || (r > 1.8 && r < 2.2) || (r > 0.45 && r < 0.55)) ok++;
      }
      a.stab = ok / f0s.length;
    }
    final flux = <double>[], jit = <double>[];
    var jumps = 0, pairs = 0;
    for (var i = 1; i < hist.length; i++) {
      final x = hist[i - 1], y = hist[i];
      if (!x.det || !y.det) continue;
      pairs++;
      flux.add((y.hE - x.hE).abs());
      var q = y.f0 / x.f0;
      if (q < 1) q = 1 / q;
      if (q > 1.12 && !(q > 1.85 && q < 2.15)) jumps++;
      if (x.f0p > 0 && y.f0p > 0) {
        final qp = y.f0p / x.f0p;
        if (qp > 0.94 && qp < 1.06) jit.add(math.log(qp).abs());
      }
    }
    a.flux = flux.isNotEmpty ? _median(flux) : 0;
    final modFactor = pairs >= 4 ? (1 - (a.flux - 3) / 4).clamp(0.0, 1.0) : 0.5;
    a.jumpFrac = pairs > 0 ? jumps / pairs : 0;
    final smoothFactor = (1 - 1.5 * a.jumpFrac).clamp(0.3, 1.0);
    a.v1conf = a.cont * a.stab * modFactor * smoothFactor;
    a.jitter = jit.length >= 3 ? _median(jit) : double.nan;

    final detRows = hist.where((x) => x.det).toList();
    double med(String key) {
      final v = [for (final x in detRows) x.get(key)].where((z) => z.isFinite).toList();
      return v.isNotEmpty ? _median(v) : double.nan;
    }

    a.inharm = med('inharm');
    a.widthRel = med('widthRel');
    a.subPk = med('subPk');
    a.mains = med('mains');
    a.hitsRatio = med('hitsRatio');
    a.hnr = med('hnr');
    a.nHarm = med('nHarm');
    final f0pList = [for (final x in detRows) x.f0p].where((z) => z > 0).toList();
    a.f0p = f0pList.isNotEmpty ? _median(f0pList) : 0;
    a.steady = pairs >= 15 && a.flux < 0.6 && jumps == 0;
    return a;
  }

  Reasons? reasons(Aggregate? agg) {
    if (agg == null || agg.nDet < 3) return null;
    final r = model.reasonThresholds;
    return Reasons(
      multiRotor: agg.inharm.isFinite ? agg.inharm > (r['inharm'] ?? 0.006) : null,
      rpmJitter: agg.jitter.isFinite ? agg.jitter > (r['jitter'] ?? 0.004) : null,
      mainsLock: agg.mains.isFinite ? agg.mains > (r['mains'] ?? 0.5) : null,
      levelSteady: agg.flux < (r['flux'] ?? 0.6),
    );
  }

  double trend() {
    final y = _strengthHist;
    final cnt = y.length;
    if (cnt < 15) return 0;
    var sx = 0.0, sy = 0.0, sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < cnt; i++) {
      sx += i;
      sy += y[i];
      sxy += i * y[i];
      sxx += i * i;
    }
    final den = cnt * sxx - sx * sx;
    return den != 0 ? (cnt * sxy - sx * sy) / den : 0;
  }

  DetectorResult _result(double t, double levelDb, FrameAnalysis? fr, Aggregate? agg, double p,
      {double f0 = 0, bool det = false, bool ignoredHit = false, bool veto = false}) {
    return DetectorResult(
      t: t,
      state: state,
      calibrating: _calibrating,
      calibProgress: _calibrating ? _calibCount / calibFrames : 1,
      conf: _conf,
      p: p,
      levelDb: levelDb,
      trend: trend(),
      fr: fr,
      agg: agg,
      reasons: agg != null ? reasons(agg) : null,
      f0: f0,
      det: det,
      ignoredHit: ignoredHit,
      veto: veto,
    );
  }
}
