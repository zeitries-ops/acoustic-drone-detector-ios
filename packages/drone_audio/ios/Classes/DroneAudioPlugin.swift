import AVFoundation
import AudioToolbox
import Flutter
import UIKit
import UserNotifications

/// Drone Kulağı yerel ses katmanı (iOS).
/// AVAudioEngine girişini 16 kHz mono'ya çevirir ve 100 ms'lik parçalar halinde Dart'a gönderir.
/// "measurement" modu iOS'un ses işlemesini (gürültü bastırma, otomatik kazanç) kapatır.
/// Info.plist'te UIBackgroundModes = audio olduğu için uygulama arka plandayken de dinler.
public class DroneAudioPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private let engine = AVAudioEngine()
  private var converter: AVAudioConverter?
  private var outFormat: AVAudioFormat?
  private var running = false
  private var targetRate: Double = 16000
  private var pending: [Float] = []
  private var chunk = 1600
  private let audioQueue = DispatchQueue(label: "drone_audio.process")

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = DroneAudioPlugin()
    instance.sosAssetKey = registrar.lookupKey(forAsset: "assets/sounds/drone_sos.wav")
    let methods = FlutterMethodChannel(name: "drone_audio/methods", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: "drone_audio/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    instance.observeSession()
  }

  // MARK: - Olay akışı

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func emit(_ value: Any) {
    DispatchQueue.main.async { [weak self] in self?.sink?(value) }
  }

  // MARK: - Yöntemler

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "permissions":
      permissionMap { result($0) }
    case "requestPermissions":
      requestPermissions { result($0) }
    case "start":
      targetRate = Double((args?["sampleRate"] as? NSNumber)?.intValue ?? 16000)
      do {
        try start()
        result(nil)
      } catch {
        result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
      }
    case "stop":
      stop()
      result(nil)
    case "isRunning":
      result(running)
    case "notify":
      let id = (args?["id"] as? NSNumber)?.intValue ?? 1
      notify(id: id, title: args?["title"] as? String ?? "", body: args?["body"] as? String ?? "")
      result(nil)
    case "vibrate":
      AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
      result(nil)
    case "openSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "moveToBackground":
      result(nil)
    case "setStrings":
      // iOS'ta kalıcı bildirim ve kanal yok; uyarı metinleri notify ile gelir.
      result(nil)
    case "setOngoingText":
      result(nil) // iOS'ta kalıcı bildirim yok; durum çubuğundaki mikrofon göstergesi yeterli
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - İzinler

  private enum MicState { case granted, denied, undetermined }

  private func micState() -> MicState {
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .granted: return .granted
      case .denied: return .denied
      default: return .undetermined
      }
    } else {
      switch AVAudioSession.sharedInstance().recordPermission {
      case .granted: return .granted
      case .denied: return .denied
      default: return .undetermined
      }
    }
  }

  private func permissionMap(_ done: @escaping ([String: Any]) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      var notif = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
      if #available(iOS 14.0, *) {
        notif = notif || settings.authorizationStatus == .ephemeral
      }
      let mic = self.micState()
      DispatchQueue.main.async {
        done([
          "microphone": mic == .granted,
          "notifications": notif,
          "microphoneBlocked": mic == .denied,
        ])
      }
    }
  }

  private func requestMic(_ done: @escaping (Bool) -> Void) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission { done($0) }
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission { done($0) }
    }
  }

  private func requestPermissions(_ done: @escaping ([String: Any]) -> Void) {
    requestMic { _ in
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
        self.permissionMap(done)
      }
    }
  }

  // MARK: - Yakalama

  private func start() throws {
    if running { return }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .measurement,
                            options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP])
    try? session.setPreferredSampleRate(48000)
    try session.setActive(true)
    // Kablolu/USB kulaklık mikrofonu takılı olsa da telefonun kendi mikrofonu dinlensin.
    if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
      try? session.setPreferredInput(builtIn)
    }

    let input = engine.inputNode
    let inFormat = input.outputFormat(forBus: 0)
    guard inFormat.sampleRate > 0, inFormat.channelCount > 0 else {
      throw NSError(domain: "drone_audio", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No microphone input found."])
    }
    guard let out = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetRate,
                                  channels: 1, interleaved: false),
          let conv = AVAudioConverter(from: inFormat, to: out) else {
      throw NSError(domain: "drone_audio", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Could not convert the audio format."])
    }
    // 48 kHz → 16 kHz: yüksek kaliteli örnekleme dönüştürücü; 8 kHz üstündeki ses 0–4 kHz bandına katlanmasın.
    conv.sampleRateConverterQuality = AVAudioQuality.high.rawValue
    outFormat = out
    converter = conv
    chunk = Int(targetRate / 10)
    audioQueue.sync { pending.removeAll() }

    input.removeTap(onBus: 0)
    input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
      self?.processBuffer(buffer)
    }
    engine.prepare()
    try engine.start()
    running = true
    emit(["type": "format", "sampleRate": Int(targetRate), "source": "ios_measurement"])
  }

  private func processBuffer(_ buffer: AVAudioPCMBuffer) {
    guard let conv = converter, let out = outFormat else { return }
    let ratio = out.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
    guard let converted = AVAudioPCMBuffer(pcmFormat: out, frameCapacity: capacity) else { return }
    var supplied = false
    var error: NSError?
    conv.convert(to: converted, error: &error) { _, status in
      if supplied {
        status.pointee = .noDataNow
        return nil
      }
      supplied = true
      status.pointee = .haveData
      return buffer
    }
    if error != nil || converted.frameLength == 0 { return }
    guard let data = converted.floatChannelData?[0] else { return }
    let samples = Array(UnsafeBufferPointer(start: data, count: Int(converted.frameLength)))
    audioQueue.async { [weak self] in
      guard let self = self else { return }
      self.pending.append(contentsOf: samples)
      while self.pending.count >= self.chunk {
        let piece = Array(self.pending[0..<self.chunk])
        self.pending.removeFirst(self.chunk)
        let bytes = piece.withUnsafeBufferPointer { Data(buffer: $0) }
        self.emit(FlutterStandardTypedData(float32: bytes))
      }
    }
  }

  private func stopEngine() {
    if engine.isRunning { engine.stop() }
    engine.inputNode.removeTap(onBus: 0)
    running = false
  }

  private func stop() {
    stopEngine()
    try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
  }

  // MARK: - Kesintiler (arama, Siri, kulaklık takılıp çıkarılması)

  private func observeSession() {
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(onInterruption(_:)),
                   name: AVAudioSession.interruptionNotification, object: nil)
    nc.addObserver(self, selector: #selector(onRouteChange(_:)),
                   name: AVAudioSession.routeChangeNotification, object: nil)
    nc.addObserver(self, selector: #selector(onMediaReset(_:)),
                   name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
  }

  private var wantRunning = false

  @objc private func onInterruption(_ note: Notification) {
    guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
    if type == .began {
      if running {
        wantRunning = true
        stopEngine()
        emit(["type": "status", "state": "interrupted"])
      }
    } else if type == .ended, wantRunning {
      restart()
    }
  }

  @objc private func onRouteChange(_ note: Notification) {
    guard running,
          let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
    if reason == .newDeviceAvailable || reason == .oldDeviceUnavailable {
      wantRunning = true
      restart()
    }
  }

  @objc private func onMediaReset(_ note: Notification) {
    if running || wantRunning {
      wantRunning = true
      restart()
    }
  }

  private func restart() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      guard let self = self, self.wantRunning else { return }
      self.stopEngine()
      do {
        try self.start()
        self.wantRunning = false
        self.emit(["type": "status", "state": "resumed"])
      } catch {
        self.emit(["type": "error", "code": "restart_failed", "message": error.localizedDescription])
      }
    }
  }

  // MARK: - Bildirim

  /// Bildirim sesi (Mors kodunda iki kez SOS). iOS özel sesi ana pakette ya da Library/Sounds'ta arar;
  /// Flutter varlığı ilk kullanımda oraya kopyalanır.
  var sosAssetKey: String?

  private func sosSound() -> UNNotificationSound {
    let name = "drone_sos.wav"
    guard let key = sosAssetKey, let src = Bundle.main.path(forResource: key, ofType: nil),
          let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return .default }
    let dir = lib.appendingPathComponent("Sounds", isDirectory: true)
    let dst = dir.appendingPathComponent(name)
    if !FileManager.default.fileExists(atPath: dst.path) {
      do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: src, toPath: dst.path)
      } catch {
        return .default
      }
    }
    return UNNotificationSound(named: UNNotificationSoundName(rawValue: name))
  }

  private func notify(id: Int, title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = sosSound()
    if #available(iOS 15.0, *) {
      content.interruptionLevel = .timeSensitive
    }
    let request = UNNotificationRequest(identifier: "drone-\(id)", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
  }
}
