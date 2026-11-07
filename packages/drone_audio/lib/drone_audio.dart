/// Drone Kulağı yerel ses katmanı.
///
/// Android: mikrofon türünde ön plan servisi + AudioRecord (mümkünse işlenmemiş kaynak).
/// iOS: AVAudioEngine, "measurement" modu (işlemesiz), arka plan ses modu.
/// Her iki platform da 16 kHz mono, 100 ms'lik Float32 parçalar gönderir.
library drone_audio;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Mikrofon ve bildirim izinlerinin durumu.
class AudioPermissions {
  const AudioPermissions({
    required this.microphone,
    required this.notifications,
    this.microphoneBlocked = false,
  });

  final bool microphone;
  final bool notifications;

  /// Kullanıcı izni kalıcı olarak reddetti; yalnızca telefon ayarlarından açılabilir.
  final bool microphoneBlocked;

  factory AudioPermissions.fromMap(Object? raw) {
    final m = (raw is Map) ? raw : const {};
    return AudioPermissions(
      microphone: m['microphone'] == true,
      notifications: m['notifications'] == true,
      microphoneBlocked: m['microphoneBlocked'] == true,
    );
  }
}

/// Yerel katmandan gelen olaylar.
sealed class DroneAudioEvent {
  const DroneAudioEvent();
}

/// 100 ms'lik ses parçası.
class AudioChunk extends DroneAudioEvent {
  const AudioChunk(this.samples);
  final Float32List samples;
}

/// Yakalama biçimi (örnekleme hızı ve kullanılan mikrofon kaynağı).
class AudioFormatInfo extends DroneAudioEvent {
  const AudioFormatInfo(this.sampleRate, this.source);
  final int sampleRate;
  final String source;
}

/// Durum değişikliği: interrupted, resumed, silenced, stopped_by_user.
class AudioStatus extends DroneAudioEvent {
  const AudioStatus(this.state);
  final String state;
}

/// Hata: mic_unavailable, fgs_failed, start_failed, restart_failed.
class AudioError extends DroneAudioEvent {
  const AudioError(this.code, this.message);
  final String code;
  final String message;
}

class DroneAudio {
  DroneAudio._();

  static const MethodChannel _methods = MethodChannel('drone_audio/methods');
  static const EventChannel _events = EventChannel('drone_audio/events');
  static Stream<DroneAudioEvent>? _stream;

  /// Yayın akışı: ses parçaları ve durum olayları.
  static Stream<DroneAudioEvent> get events {
    return _stream ??= _events.receiveBroadcastStream().map(_parse).where((e) => e != null).cast<DroneAudioEvent>().asBroadcastStream();
  }

  static DroneAudioEvent? _parse(dynamic raw) {
    if (raw is Float32List) return AudioChunk(raw);
    if (raw is Float64List) return AudioChunk(Float32List.fromList(raw));
    if (raw is Map) {
      switch (raw['type']) {
        case 'format':
          return AudioFormatInfo((raw['sampleRate'] as num?)?.toInt() ?? 16000, '${raw['source'] ?? ''}');
        case 'status':
          return AudioStatus('${raw['state'] ?? ''}');
        case 'error':
          return AudioError('${raw['code'] ?? 'error'}', '${raw['message'] ?? ''}');
      }
    }
    return null;
  }

  static Future<AudioPermissions> permissions() async =>
      AudioPermissions.fromMap(await _methods.invokeMethod<Object?>('permissions'));

  static Future<AudioPermissions> requestPermissions() async =>
      AudioPermissions.fromMap(await _methods.invokeMethod<Object?>('requestPermissions'));

  /// Dinlemeyi başlatır. Android'de kalıcı bir "dinliyor" bildirimi görünür.
  static Future<void> start({int sampleRate = 16000}) =>
      _methods.invokeMethod<void>('start', {'sampleRate': sampleRate});

  static Future<void> stop() => _methods.invokeMethod<void>('stop');

  static Future<bool> isRunning() async => (await _methods.invokeMethod<bool>('isRunning')) ?? false;

  /// Drone uyarı bildirimi gönderir (uygulama arka plandayken de görünür).
  static Future<void> notify({required int id, required String title, required String body}) =>
      _methods.invokeMethod<void>('notify', {'id': id, 'title': title, 'body': body});

  static Future<void> vibrate([List<int> patternMs = const [0, 400, 150, 400, 150, 400]]) =>
      _methods.invokeMethod<void>('vibrate', {'pattern': patternMs});

  /// Uygulamanın sistem ayarları sayfasını açar (reddedilmiş izinler için).
  static Future<void> openSettings() => _methods.invokeMethod<void>('openSettings');

  /// Android: geri tuşunda uygulamayı kapatmak yerine arka plana alır (dinleme sürer).
  static Future<void> moveToBackground() => _methods.invokeMethod<void>('moveToBackground');

  /// Bildirim metinleri uygulamanın dilinde (Android: kalıcı bildirim, "Durdur" düğmesi, kanal adları).
  /// Anahtarlar: ongoingTitle, ongoingText, stop, channelListen, channelListenDesc, channelAlert, channelAlertDesc.
  static Future<void> setStrings(Map<String, String> strings) => _methods.invokeMethod<void>('setStrings', strings);

  /// Android'deki kalıcı "dinliyor" bildiriminin metnini günceller.
  static Future<void> setOngoingText({String? title, String? body}) =>
      _methods.invokeMethod<void>('setOngoingText', {'title': title, 'body': body});
}
