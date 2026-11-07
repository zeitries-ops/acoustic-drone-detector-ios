import 'dart:async';
import 'dart:typed_data';

import 'package:drone_audio/drone_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/detector.dart';
import '../l10n/strings.dart';
import 'brand.dart';
import 'resampler.dart';
import 'spectrogram.dart';
import 'store.dart';
import 'yamnet.dart';

const int kRate = 16000;
const int kFrame = 4096;
const int kHop = 1600;

/// İlk uyarıda titreşim de SOS: ··· −−− ···
const List<int> _sosVibration = [0, 120, 100, 120, 100, 120, 300, 360, 100, 360, 100, 360, 300, 120, 100, 120, 100, 120];

/// Mikrofon → dedektör → arayüz/bildirim akışını yöneten durum nesnesi.
class Monitor extends ChangeNotifier with WidgetsBindingObserver {
  Monitor(this.store) {
    settings = store.loadSettings();
    events = store.loadEvents();
    ignored = store.loadIgnored();
    detector = _newDetector();
    WidgetsBinding.instance.addObserver(this);
  }

  final AppStore store;
  late AppSettings settings;
  late List<DetectionEvent> events;
  late List<IgnoredSignature> ignored;
  late DroneDetector detector;
  final SpectrogramBuffer spectrogram = SpectrogramBuffer();

  bool listening = false;
  bool starting = false;

  /// init() bitti: dinlemenin sürüp sürmediği artık biliniyor.
  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  /// Bu açılışta ortam seçimi soruldu mu. Monitor uygulama süreci başına bir kez oluşur ve arka plandan
  /// dönüşte aynı kalır; böylece soru yalnızca soğuk açılışta gelir.
  bool zoneAskedThisLaunch = false;
  String? error;
  String? notice;
  AudioPermissions? permissions;
  DetectorResult? last;
  int sampleRate = kRate;
  String source = '';
  DateTime? listenStarted;
  DetectionEvent? current;
  bool foreground = true;
  double trendAvg = 0;
  int steadyFor = 0;

  /// YAMNet ikinci görüşü; model yüklenemezse null kalır ve yalnızca harmonik dedektör çalışır.
  YamnetRunner? _yam;
  bool get secondOpinion => detector.fused;

  StreamSubscription<DroneAudioEvent>? _sub;
  StreamResampler? _resampler;
  final Float32List _ring = Float32List(kFrame);
  final Float32List _frame = Float32List(kFrame);
  int _ringPos = 0;
  int _filled = 0;
  int _sinceHop = 0;
  double _t = 0;
  DateTime _lastHaptic = DateTime.fromMillisecondsSinceEpoch(0);
  DetectorState? _lastNotifiedState;

  DroneDetector _newDetector() {
    final d = DroneDetector(sampleRate: kRate, fftSize: kFrame, preset: settings.preset, sensitivity: settings.sensitivity);
    d.setIgnored(ignored);
    d.setFusion(_yam?.ready ?? false);
    return d;
  }

  Future<void> _ensureYamnet() async {
    final y = _yam ??= YamnetRunner(onResult: (p) => detector.second.update(p, _t));
    if (!y.ready) await y.start();
    y.reset();
  }

  Future<void> init() async {
    try {
      permissions = await DroneAudio.permissions();
      listening = await DroneAudio.isRunning();
      if (listening) {
        await _ensureYamnet();
        detector.setFusion(_yam?.ready ?? false);
        _subscribe();
      }
    } catch (_) {
      // yerel katman yoksa (ör. test ortamı) sessizce devam et
    }
    if (!_ready.isCompleted) _ready.complete();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      DroneAudio.permissions().then((p) {
        permissions = p;
        notifyListeners();
      }).catchError((_) {});
    }
  }

  // ------------------------------------------------------------------ dinleme

  Future<void> toggle() => listening ? stop() : start();

  Future<void> start() async {
    if (listening || starting) return;
    starting = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      var p = await DroneAudio.permissions();
      if (!p.microphone || !p.notifications) p = await DroneAudio.requestPermissions();
      permissions = p;
      if (!p.microphone) {
        error = p.microphoneBlocked ? S.current.errMicBlocked(app: kAppName) : S.current.errMicNeeded;
        starting = false;
        notifyListeners();
        return;
      }
      await _ensureYamnet();
      detector = _newDetector();
      _ringPos = 0;
      _filled = 0;
      _sinceHop = 0;
      _t = 0;
      _resampler = null;
      sampleRate = kRate;
      trendAvg = 0;
      steadyFor = 0;
      last = null;
      spectrogram.clear();
      _subscribe();
      await _sendNativeStrings();
      await DroneAudio.start(sampleRate: kRate);
      listening = true;
      listenStarted = DateTime.now();
    } on PlatformException catch (e) {
      error = S.current.errStart(reason: _errorText(e.code, e.message ?? ''));
      await _sub?.cancel();
      _sub = null;
    } catch (e) {
      error = S.current.errStart(reason: '$e');
      await _sub?.cancel();
      _sub = null;
    }
    starting = false;
    notifyListeners();
  }

  Future<void> stop({String? message}) async {
    try {
      await DroneAudio.stop();
    } catch (_) {}
    await _sub?.cancel();
    _sub = null;
    _endEvent();
    listening = false;
    last = null;
    listenStarted = null;
    if (message != null) notice = message;
    notifyListeners();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = DroneAudio.events.listen(_onAudio, onError: (Object e) {
      error = S.current.errStream(reason: '$e');
      notifyListeners();
    });
  }

  void _onAudio(DroneAudioEvent ev) {
    switch (ev) {
      case final AudioFormatInfo f:
        sampleRate = f.sampleRate;
        source = f.source;
        _resampler = f.sampleRate != kRate ? StreamResampler(f.sampleRate, kRate) : null;
        notifyListeners();
      case final AudioChunk c:
        final rs = _resampler;
        _feed(rs != null ? rs.process(c.samples) : c.samples);
      case final AudioStatus s:
        _onStatus(s.state);
      case final AudioError e:
        error = _errorText(e.code, e.message);
        if (listening) stop();
        notifyListeners();
    }
  }

  /// Yerel taraftan gelen hata kodu → uygulamanın dilinde ileti (yerel ileti yalnızca bilinmeyen kodlarda).
  String _errorText(String code, String message) {
    final t = S.current;
    switch (code) {
      case 'mic_unavailable':
        return t.errMicUnavailable;
      case 'mic_busy':
        return t.errMicBusy;
      case 'fgs_failed':
        return t.errBackground;
      case 'read_failed':
        return t.errRead;
      case 'no_permission':
        return t.errMicNeeded;
      default:
        return message.isNotEmpty ? message : t.errMic(code: code);
    }
  }

  /// Android bildirim metinleri (kalıcı bildirim, "Durdur", kanal adları) uygulamanın dilinde.
  Future<void> _sendNativeStrings() async {
    final t = S.current;
    try {
      await DroneAudio.setStrings({
        'ongoingTitle': t.ongoingTitle(app: kAppShortName),
        'ongoingText': t.ongoingText,
        'stop': t.stop,
        'channelListen': t.channelListen,
        'channelListenDesc': t.channelListenDesc,
        'channelAlert': t.channelAlert,
        'channelAlertDesc': t.channelAlertDesc,
      });
    } catch (_) {}
  }

  void _onStatus(String state) {
    switch (state) {
      case 'interrupted':
        notice = S.current.noticeInterrupted;
      case 'silenced':
        notice = S.current.noticeSilenced;
      case 'resumed':
        notice = null;
        detector.recalibrate();
      case 'stopped_by_user':
        stop(message: S.current.noticeStopped);
        return;
    }
    notifyListeners();
  }

  void _feed(Float32List x) {
    _yam?.feed(x);
    for (var i = 0; i < x.length; i++) {
      _ring[_ringPos] = x[i];
      _ringPos = (_ringPos + 1) % kFrame;
      if (_filled < kFrame) _filled++;
      _sinceHop++;
      if (_sinceHop >= kHop && _filled >= kFrame) {
        _sinceHop = 0;
        for (var j = 0; j < kFrame; j++) {
          _frame[j] = _ring[(_ringPos + j) % kFrame];
        }
        _t += kHop / kRate;
        _process();
      }
    }
  }

  void _process() {
    final r = detector.process(_frame, _t);
    last = r;
    if (r.agg != null) trendAvg += 0.08 * (r.trend - trendAvg);
    // Spektrum yalnızca ekran görünürken çizilir: arka planda pil harcamasın; iOS arka planda GPU'ya izin vermez.
    if (foreground) spectrogram.push(detector.dB, detector.binHz, r.state, r.fr?.harm);

    final now = DateTime.now();
    if (r.state == DetectorState.drone) {
      final f0 = (r.agg?.f0p ?? 0) > 0 ? r.agg!.f0p : r.f0;
      if (current == null) {
        current = DetectionEvent(startMs: now.millisecondsSinceEpoch, f0: f0, peak: r.fr?.strength ?? 0);
        events.insert(0, current!);
        store.saveEvents(events);
        _alert(first: true, f0: f0);
      } else {
        current!.f0 = f0;
        final s = r.fr?.strength ?? 0.0;
        if (s > current!.peak) current!.peak = s;
        if (foreground && now.difference(_lastHaptic).inSeconds >= 10) _alert(first: false, f0: f0);
      }
      steadyFor = (r.agg?.steady ?? false) ? steadyFor + 1 : 0;
    } else if (current != null) {
      _endEvent();
      steadyFor = 0;
    }
    if (_lastNotifiedState != r.state) {
      _lastNotifiedState = r.state;
      DroneAudio.setOngoingText(body: S.current.ongoingStatus(state: stateWord(r.state))).catchError((_) {});
    }
    notifyListeners();
  }

  void _alert({required bool first, required double f0}) {
    _lastHaptic = DateTime.now();
    if (settings.vibrate) {
      if (foreground) HapticFeedback.heavyImpact();
      DroneAudio.vibrate(first ? _sosVibration : const [0, 250]).catchError((_) {});
    }
    if (first && settings.notify && !foreground) {
      final id = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 100000;
      DroneAudio.notify(
        id: id,
        title: S.current.alertTitle,
        body: S.current.alertBody(hz: f0.round()),
      ).catchError((_) {});
    }
  }

  void _endEvent() {
    final c = current;
    if (c == null) return;
    c.endMs = DateTime.now().millisecondsSinceEpoch;
    current = null;
    store.saveEvents(events);
  }

  // ---------------------------------------------------------------- eylemler

  void recalibrate() {
    _endEvent();
    detector.recalibrate();
    notifyListeners();
  }

  /// Şu an duyulan sesi "benim cihazım" olarak kaydeder; bir dahaki sefere kendiliğinden yoksayılır.
  void ignoreCurrent() {
    final sig = detector.signature();
    if (current != null) {
      current!.ignored = true;
      _endEvent();
    }
    detector.learnAmbient(sig);
    if (sig != null) {
      ignored = [...ignored, sig];
      store.saveIgnored(ignored);
    }
    notifyListeners();
  }

  void removeIgnored(IgnoredSignature s) {
    ignored = ignored.where((x) => !identical(x, s)).toList();
    detector.setIgnored(ignored);
    store.saveIgnored(ignored);
    notifyListeners();
  }

  void clearEvents() {
    current = null;
    events = [];
    store.saveEvents(events);
    notifyListeners();
  }

  void setPreset(DronePreset p) {
    settings.preset = p;
    detector.setPreset(p);
    store.saveSettings(settings);
    notifyListeners();
  }

  void setSensitivity(double s) {
    settings.sensitivity = s;
    detector.setSensitivity(s);
    store.saveSettings(settings);
    notifyListeners();
  }

  void setNotify(bool v) {
    settings.notify = v;
    store.saveSettings(settings);
    if (v) {
      DroneAudio.requestPermissions().then((p) {
        permissions = p;
        notifyListeners();
      }).catchError((_) {});
    }
    notifyListeners();
  }

  void setVibrate(bool v) {
    settings.vibrate = v;
    store.saveSettings(settings);
    if (v) DroneAudio.vibrate(const [0, 60]).catchError((_) {});
    notifyListeners();
  }

  Future<void> openSettings() => DroneAudio.openSettings().catchError((_) {});

  /// Android geri tuşu: dinlerken uygulamayı kapatmak yerine arka plana al.
  Future<void> moveToBackground() => DroneAudio.moveToBackground().catchError((_) {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _yam?.dispose();
    spectrogram.dispose();
    super.dispose();
  }
}

String stateWord(DetectorState s, [S? strings]) {
  final t = strings ?? S.current;
  switch (s) {
    case DetectorState.calibrating:
      return t.stateLearning;
    case DetectorState.clear:
      return t.stateClear;
    case DetectorState.suspect:
      return t.stateSuspect;
    case DetectorState.drone:
      return t.stateDrone;
  }
}
