# Acoustic Drone Detector – iOS

Detects drone propeller sound with the iPhone or iPad microphone and sends an alert, also in the background.
Everything runs on the device; audio is never recorded or sent anywhere. 27 languages.

**Support:** open an issue → [Issues](https://github.com/zeitries-ops/acoustic-drone-detector-ios/issues)
· **Privacy policy:** [PRIVACY.md](PRIVACY.md)

---

Bu depo, uygulamanın Flutter kaynağını ve **Xcode'da açılmaya hazır iOS projesini** (`ios/`) içerir.
Mac'te klonla, iki komut çalıştır, Xcode'da Archive al.

## Mac'te açma

Gerekenler: Xcode 16+, [Flutter](https://docs.flutter.dev/get-started/install/macos) (stable), CocoaPods
(`sudo gem install cocoapods`).

```bash
git clone https://github.com/zeitries-ops/acoustic-drone-detector-ios.git
cd acoustic-drone-detector-ios
flutter pub get
flutter build ios --config-only --no-codesign   # Flutter ayarlarını üretir, pod install çalıştırır
open ios/Runner.xcworkspace          # .xcodeproj değil, .xcworkspace
```

Xcode'da **Runner → Signing & Capabilities**: kendi ekibini (Team) seç. Paket kimliği
`com.osmanemreaydin.droneKulagi`; ilk App Store yüklemesinden sonra değiştirilemez.
**Background Modes → Audio** ve **Time Sensitive Notifications** hazır gelir.

Telefonda denemek için iPhone'u bağla ve Run'a bas. Mağazaya yüklemek için **Product → Archive →
Distribute App → App Store Connect**. Ayrıntılı adımlar ve App Store Connect alanları: [RELEASE.md](RELEASE.md).

## Projede hazır olanlar

- iPhone + iPad (iOS 15+), iPad'de dört yön, Bölünmüş Ekran, Slide Over ve Stage Manager
- Arka planda dinleme (`UIBackgroundModes: audio`), zamana duyarlı bildirim, SOS bildirim sesi
- Mikrofon izni metni 27 dilde, `CFBundleLocalizations` 27 dil
- Gizlilik bildirimi (`PrivacyInfo.xcprivacy`): veri toplanmaz, izleme yok
- Şifreleme beyanı (`ITSAppUsesNonExemptEncryption = NO`), siyah açılış ekranı, simgeler
- Ses `AVAudioSession` `.measurement` modunda alınır (iOS'un otomatik kazanç, gürültü bastırma ve
  yüksek geçiren filtresi kapalı); kulaklık takılı olsa da telefonun kendi mikrofonu kullanılır

## Klasörler

| Yol | İçerik |
|---|---|
| `ios/` | Xcode projesi (Runner), Podfile, Info.plist, dil dosyaları |
| `lib/` | Uygulama (Dart): arayüz, algılama, YAMNet |
| `packages/drone_audio/` | Mikrofon ve bildirim eklentisi (iOS: Swift) |
| `l10n/` | Çeviriler (27 dil, JSON); `python3 tool/gen_l10n.py` Dart ve iOS dosyalarını üretir |
| `assets/` | YAMNet modeli (Apache 2.0), Poppins yazı tipi (OFL), SOS sesi |
| `store/app_store/` | App Store metinleri, inceleme notu, ekran görüntüleri (iPhone 6,9", iPad 13") |
| `test/` | Testler (`flutter test`) |

`ios/` klasörü `tool/setup_platforms.sh` ile üretildi; yeniden üretmek gerekirse:
`IOS_BUNDLE_ID=com.osmanemreaydin.droneKulagi IOS_TEAM_ID=EKIP bash tool/setup_platforms.sh`.

## Teşekkür ve lisanslar

- **YAMNet** (Google), Apache 2.0 – `assets/models/YAMNET_LICENSE.txt`
- **Poppins** yazı tipi, SIL Open Font License – `assets/fonts/OFL-Poppins.txt`
- Algılama modelleri yalnızca serbest verilerle eğitildi: [Svanström Drone-detection-dataset](https://github.com/DroneDetectionThesis/Drone-detection-dataset)
  (CC0) ve [ESC-50](https://github.com/karolpiczak/ESC-50) ESC-10 alt kümesi (CC BY; K. J. Piczak,
  "ESC: Dataset for Environmental Sound Classification", ACM MM 2015).

Uygulama kodu için ayrı bir lisans verilmemiştir (tüm hakları saklıdır).
