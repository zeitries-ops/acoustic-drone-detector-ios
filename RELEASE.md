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
`com.zeitries.dronedetector` (ilk yüklemeden sonra değiştirilemez). Ekip (Team) Xcode'da seçilir.

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

Uygulama 27 dilde (cihaz dilini izler; mikrofon izni metni de her dilde). Mağaza metni 19 App Store yerelleştirmesinde hazır:
`store/app_store/<dil>/` → en-US, uk, ru, pl, ro, he, ar-SA, tr, de-DE, fr-FR, es-ES, es-MX, fi, sv, zh-Hant, ja, ko, hi, ur.
App Store Connect'te her dili **App Information → Localizable Information** ve sürüm sayfasında ekle; ad her dilde
"Acoustic Drone Detector". Birmanca, Litvanca, Letonca, Estonca, Bulgarca, Farsça, Azerice, Ermenice ve Gürcüce
App Store'un desteklediği diller değil; bu ülkelerde İngilizce sayfa görünür (uygulama yine kendi dilinde açılır).
Ekran görüntüleri tek takım (İngilizce); dil eklenince App Store hepsine İngilizce görüntüleri kullanır.

| Alan | Değer |
|---|---|
| Ad, alt başlık, tanıtım metni, açıklama, anahtar kelimeler | `store/app_store/<dil>/*.txt` (inceleme notu yalnızca `en-US/review_notes.txt`) |
| Destek URL'si / Gizlilik politikası URL'si | `support_url.txt` / `privacy_url.txt` (depo herkese açık kalmalı) |
| Kategori | Utilities |
| Yaş sınırı | Tüm sorulara "None" → 4+ |
| App Privacy | **Data Not Collected** (ses cihazdan çıkmaz, hesap/analitik/reklam yok) |
| Ekran görüntüleri | Başlıklı olanlar: `store/app_store/framed/` → iPhone 6,9" (1320×2868) `iphone_1…5.png`, iPad 13" (2064×2752) `ipad_1…4.png`. Ham ekranlar `screenshots/`; yeniden üretmek için `python3 tool/make_store_shots.py` |
| İnceleme notu (App Review Information → Notes) | `review_notes.txt` |
| Telif hakkı | "2026 Adın Soyadın" |
| Fiyat | Planlanan 9,99 USD (ücretli). Önce App Store Connect → Business: **Paid Applications** sözleşmesi, banka ve vergi bilgileri. TestFlight için gerekmez |

Önce **TestFlight** ile kendi telefonunda dene, sonra "Add for Review".

## İnceleme açısından dikkat

- Arka planda mikrofon kullanımı (UIBackgroundModes: audio) inceleme notunda açıklandı; iOS dinlerken durum çubuğunda
  mikrofon göstergesini kendiliğinden gösterir.
- Uygulama güvenlik amaçlı tek kaynak olmadığını açıklamada ve "How it works" bölümünde söylüyor.
- YAMNet modeli Apache 2.0 lisanslı; lisans metni uygulamada Settings → How it works → Licenses altında.
