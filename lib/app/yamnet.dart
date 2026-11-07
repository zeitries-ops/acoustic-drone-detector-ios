import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/second_opinion.dart';

/// Google YAMNet'i (16 bit ağırlıklı TFLite, Apache 2.0) ayrı bir isolate'te çalıştırır.
///
/// 16 kHz ses alır; her 0,48 sn'de son 0,975 sn'yi modele verir, 1024 sayılık gömmeden
/// drone olasılığını hesaplar ve [onResult] ile bildirir. Model yüklenemezse [ready] false kalır
/// ve uygulama yalnızca harmonik dedektörle çalışır.
class YamnetRunner {
  YamnetRunner({required this.onResult});

  static const String asset = 'assets/models/yamnet_embed.tflite';
  static const int win = 15600;
  static const int hop = 7680;

  final void Function(double p) onResult;

  Isolate? _iso;
  ReceivePort? _recv;
  SendPort? _send;
  bool _busy = false;
  String? error;
  int skipped = 0;

  final Float32List _ring = Float32List(win);
  int _pos = 0, _filled = 0, _since = 0;

  bool get ready => _send != null;

  Future<bool> start() async {
    if (ready) return true;
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final recv = ReceivePort();
      _recv = recv;
      final done = Completer<void>();
      recv.listen((m) {
        if (m is SendPort) {
          _send = m;
          if (!done.isCompleted) done.complete();
        } else if (m is double) {
          _busy = false;
          onResult(m);
        } else if (m is String) {
          _busy = false;
          error = m;
          if (!done.isCompleted) done.complete();
        }
      });
      _iso = await Isolate.spawn(_worker, [recv.sendPort, TransferableTypedData.fromList([bytes])],
          debugName: 'yamnet');
      await done.future.timeout(const Duration(seconds: 15));
    } catch (e) {
      error = '$e';
    }
    if (!ready) dispose();
    return ready;
  }

  /// Yeni dinlemede pencereyi boşalt.
  void reset() {
    _pos = 0;
    _filled = 0;
    _since = 0;
    _busy = false;
  }

  void feed(Float32List x) {
    if (!ready) return;
    for (var i = 0; i < x.length; i++) {
      _ring[_pos] = x[i];
      _pos = (_pos + 1) % win;
      if (_filled < win) _filled++;
      _since++;
      if (_since >= hop && _filled >= win) {
        _since = 0;
        _run();
      }
    }
  }

  void _run() {
    final send = _send;
    if (send == null) return;
    if (_busy) {
      skipped++; // önceki pencere hâlâ işleniyor: bunu atla
      return;
    }
    final buf = Float32List(win);
    for (var j = 0; j < win; j++) {
      buf[j] = _ring[(_pos + j) % win];
    }
    _busy = true;
    send.send(TransferableTypedData.fromList([buf]));
  }

  void dispose() {
    _iso?.kill(priority: Isolate.immediate);
    _iso = null;
    _recv?.close();
    _recv = null;
    _send = null;
  }
}

void _worker(List<Object> args) {
  final reply = args[0] as SendPort;
  try {
    final bytes = (args[1] as TransferableTypedData).materialize().asUint8List();
    final interp = Interpreter.fromBuffer(bytes, options: InterpreterOptions()..threads = 1);
    interp.allocateTensors();
    final input = interp.getInputTensor(0);
    final output = interp.getOutputTensor(0);
    final port = ReceivePort();
    reply.send(port.sendPort);
    port.listen((m) {
      try {
        input.data = (m as TransferableTypedData).materialize().asUint8List();
        interp.invoke();
        final e = Uint8List.fromList(output.data).buffer.asFloat32List();
        reply.send(yamnetHead(e));
      } catch (e) {
        reply.send('$e');
      }
    });
  } catch (e) {
    reply.send('$e');
  }
}
