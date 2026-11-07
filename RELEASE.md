# iOS yayın adımları (App Store)

Uygulama: **Acoustic Drone Detector** · ana ekran adı "Drone Detector" · sürüm 2.1.0 (derleme 3) · iPhone + iPad, iOS 15+.

## 1. Mac'te hazırlık (bir kez)

- Xcode 16 veya üstü, Flutter (stable), CocoaPods (`sudo gem install cocoapods`).
- Apple Developer hesabında oturum açık Xcode (Xcode → Settings → Accounts).

## 2. Projeyi aç

```bash
git clone https://github.com/zeitries-ops/acoustic-drone-detector-ios.git && cd acoustic-drone-detector-ios
flutter pub get
flutter build ios --config-only --no-codesign
```

iOS projesi (`ios/`) hazır gelir; ayrıca betik çalıştırmak gerekmez. Paket kimliği
`com.osmanemreaydin.droneKulagi` (ilk yüklemeden sonra değiştirilemez). Ekip (Team) Xcode'da seçilir.

## 3. Önce gerçek cihazda dene

```bash
open ios/Runner.xcworkspace
```

Signing & Capabilities sekmesinde kendi ekibini (Team) seç; **Background Modes → Audio** ve **Time Sensitive Notifications** görünmeli.
iPhone'u bağla, Run. Kontrol et: dinleme arka planda sürüyor mu, drone sesinde SOS sesli bildirim geliyor mu,
Odak (Focus) modunda bildirim görünüyor mu.

## 4. Arşivle ve yükle

```bash
flutter build ipa --release
# ya da Xcode → Product → Archive
```

Çıktı: `build/ios/ipa/*.ipa`. Yüklemek için **Transporter** uygulamasına sürükle (Mac App Store'dan ücretsiz)
ya da Xcode → Product → Archive → Distribute App → App Store Connect.

## 5. App Store Connect

Yeni uygulama: Platform iOS, ad "Acoustic Drone Detector", birincil dil English (U.S.), paket kimliği yukarıdaki, SKU serbest.

Uygulama 27 dilde (cihaz dilini izler; mikrofon izni metni de her dilde). Mağaza metni şimdilik yalnızca İngilizce;
App Store Connect'te başka diller eklenmezse her ülkede İngilizce sayfa görünür.

| Alan | Değer |
|---|---|
| Ad, alt başlık, tanıtım metni, açıklama, anahtar kelimeler | `store/app_store/en-US/*.txt` |
| Destek URL'si / Gizlilik politikası URL'si | `support_url.txt` / `privacy_url.txt` (depo herkese açık kalmalı) |
| Kategori | Utilities |
| Yaş sınırı | Tüm sorulara "None" → 4+ |
| App Privacy | **Data Not Collected** (ses cihazdan çıkmaz, hesap/analitik/reklam yok) |
| Ekran görüntüleri | iPhone 6,9" (1320×2868): `store/app_store/screenshots/iphone_*.png` · iPad 13" (2064×2752): `ipad_*.png` |
| İnceleme notu (App Review Information → Notes) | `review_notes.txt` |
| Telif hakkı | "2026 Adın Soyadın" |
| Fiyat | Ücretsiz (ya da seçtiğin) |

Önce **TestFlight** ile kendi telefonunda dene, sonra "Add for Review".

## İnceleme açısından dikkat

- Arka planda mikrofon kullanımı (UIBackgroundModes: audio) inceleme notunda açıklandı; iOS dinlerken durum çubuğunda
  mikrofon göstergesini kendiliğinden gösterir.
- Uygulama güvenlik amaçlı tek kaynak olmadığını açıklamada ve "How it works" bölümünde söylüyor.
- YAMNet modeli Apache 2.0 lisanslı; lisans metni uygulamada Settings → How it works → Licenses altında.
