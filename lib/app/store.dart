import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/detector.dart';

/// Bir drone tespiti (kayıt satırı).
class DetectionEvent {
  DetectionEvent({required this.startMs, this.endMs, required this.f0, required this.peak, this.ignored = false});

  final int startMs;
  int? endMs;
  double f0;
  double peak;
  bool ignored;

  Duration? get duration => endMs == null ? null : Duration(milliseconds: endMs! - startMs);

  Map<String, Object?> toJson() => {'s': startMs, 'e': endMs, 'f': f0, 'p': peak, 'i': ignored};

  static DetectionEvent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final s = (raw['s'] as num?)?.toInt();
    if (s == null) return null;
    return DetectionEvent(
      startMs: s,
      endMs: (raw['e'] as num?)?.toInt(),
      f0: (raw['f'] as num?)?.toDouble() ?? 0,
      peak: (raw['p'] as num?)?.toDouble() ?? 0,
      ignored: raw['i'] == true,
    );
  }
}

class AppSettings {
  AppSettings({
    this.preset = DronePreset.multi,
    this.sensitivity = 0.5,
    this.notify = true,
    this.vibrate = true,
  });

  DronePreset preset;
  double sensitivity;
  bool notify;
  bool vibrate;
}

/// Ayarlar, tespit kaydı ve yoksayılan sesler. Hepsi yalnızca bu telefonda saklanır.
class AppStore {
  AppStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppStore> open() async => AppStore(await SharedPreferences.getInstance());

  AppSettings loadSettings() {
    final p = _prefs.getInt('preset') ?? 0;
    return AppSettings(
      preset: DronePreset.values[p.clamp(0, DronePreset.values.length - 1)],
      sensitivity: (_prefs.getDouble('sens') ?? 0.5).clamp(0.0, 1.0),
      notify: _prefs.getBool('notify') ?? true,
      vibrate: _prefs.getBool('vibrate') ?? true,
    );
  }

  Future<void> saveSettings(AppSettings s) async {
    await _prefs.setInt('preset', s.preset.index);
    await _prefs.setDouble('sens', s.sensitivity);
    await _prefs.setBool('notify', s.notify);
    await _prefs.setBool('vibrate', s.vibrate);
  }

  List<DetectionEvent> loadEvents() {
    try {
      final raw = jsonDecode(_prefs.getString('events') ?? '[]');
      if (raw is! List) return [];
      return raw.map(DetectionEvent.fromJson).whereType<DetectionEvent>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEvents(List<DetectionEvent> events) =>
      _prefs.setString('events', jsonEncode(events.take(200).map((e) => e.toJson()).toList()));

  List<IgnoredSignature> loadIgnored() {
    try {
      final raw = jsonDecode(_prefs.getString('ignored') ?? '[]');
      if (raw is! List) return [];
      return raw.map(IgnoredSignature.fromJson).whereType<IgnoredSignature>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveIgnored(List<IgnoredSignature> list) =>
      _prefs.setString('ignored', jsonEncode(list.map((e) => e.toJson()).toList()));
}
