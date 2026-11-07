#!/usr/bin/env bash
# Android ve iOS proje klasörlerini oluşturur ve Acoustic Drone Detector ayarlarını uygular.
# Kullanım:  bash tool/setup_platforms.sh        (depo kökünde)
# Kimlik değiştirmek için:  ORG=com.sirketim bash tool/setup_platforms.sh
# iOS yayın için:  IOS_BUNDLE_ID=com.osmanemreaydin.droneKulagi IOS_TEAM_ID=ABCDE12345 bash tool/setup_platforms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ORG="${ORG:-com.osmanemreaydin}"
APP_NAME="Drone Detector"  # ana ekran etiketi (kısa); mağaza ve uygulama içi ad: lib/app/brand.dart
MIC_TEXT="Acoustic Drone Detector listens through the microphone to detect drone propeller sound. Audio is never recorded or sent off the phone."

# Var olan dosyaların üzerine yazmaz; yalnızca eksik platform dosyalarını üretir.
flutter create --org "$ORG" --project-name drone_kulagi --platforms=ios .

# ---- Android
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ]; then
  sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/" "$MANIFEST" && rm -f "$MANIFEST.bak"
fi
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  if [ -f "assets/icon/android/mipmap-$d/ic_launcher.png" ] && [ -d "android/app/src/main/res/mipmap-$d" ]; then
    cp "assets/icon/android/mipmap-$d/ic_launcher.png" "android/app/src/main/res/mipmap-$d/ic_launcher.png"
  fi
done

# Açılış ekranı zemini: beyaz yerine tam siyah (#000000; AMOLED'de pil dostu)
for f in android/app/src/main/res/drawable/launch_background.xml android/app/src/main/res/drawable-v21/launch_background.xml; do
  if [ -f "$f" ]; then
    sed -i.bak 's#@android:color/white#@color/drone_launch_bg#; s#?android:colorBackground#@color/drone_launch_bg#' "$f" && rm -f "$f.bak"
  fi
done
mkdir -p android/app/src/main/res/values
cat > android/app/src/main/res/values/drone_colors.xml <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="drone_launch_bg">#FF000000</color>
</resources>
XML
# tflite_flutter eklentisi Java 11, Kotlin 17 hedefliyor; Gradle bu uyumsuzluğu hata değil uyarı saysın.
if [ -f android/gradle.properties ] && ! grep -q "kotlin.jvm.target.validation.mode" android/gradle.properties; then
  echo "kotlin.jvm.target.validation.mode=warning" >> android/gradle.properties
fi
# LiteRT GPU parçası kullanılmıyor (YAMNet işlemcide çalışır): APK'dan çıkar.
for G in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$G" ] && ! grep -q "litert-gpu" "$G"; then
    if [[ "$G" == *.kts ]]; then
      printf '\nconfigurations.all { exclude(group = "com.google.ai.edge.litert", module = "litert-gpu") }\n' >> "$G"
    else
      printf "\nconfigurations.all { exclude group: 'com.google.ai.edge.litert', module: 'litert-gpu' }\n" >> "$G"
    fi
  fi
done
# LiteRT (YAMNet): R8 küçültmesinde kullanılmayan GPU sınıfları için uyarıları sustur, çalışma zamanını koru.
# Flutter Gradle eklentisi app/proguard-rules.pro dosyasını sürüm derlemesine kendiliğinden ekler.
cat > android/app/proguard-rules.pro <<'PRO'
-keep class org.tensorflow.lite.** { *; }
-keep class com.google.ai.edge.litert.** { *; }
-dontwarn org.tensorflow.lite.**
-dontwarn com.google.ai.edge.litert.**
PRO

# Android 13+ uygulama dili listesi (Ayarlar → Uygulamalar → Dil): tool/gen_l10n.py üretir
if [ -f "$MANIFEST" ]; then
  mkdir -p android/app/src/main/res/xml
  cp tool/platform_l10n/android/locales_config.xml android/app/src/main/res/xml/locales_config.xml
  if ! grep -q "android:localeConfig" "$MANIFEST"; then
    sed -i.bak 's#<application#<application android:localeConfig="@xml/locales_config"#' "$MANIFEST" && rm -f "$MANIFEST.bak"
  fi
fi

# ---- iOS
# Diller: mikrofon izni metni her dilde (InfoPlist.strings); Xcode projesine ios_project.rb ekler
if [ -d ios/Runner ]; then
  cp -R tool/platform_l10n/ios/*.lproj ios/Runner/
fi
# Gizlilik bildirimi: veri toplanmaz, izleme yok. Gerekçeli API'ler: uygulama ayarları (UserDefaults),
# uygulama klasöründeki dosya bilgileri ve geçen süre ölçümü (Flutter ve TensorFlow Lite kullanır).
if [ -d ios/Runner ]; then
  cat > ios/Runner/PrivacyInfo.xcprivacy <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array><string>CA92.1</string></array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array><string>C617.1</string></array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategorySystemBootTime</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array><string>35F9.1</string></array>
		</dict>
	</array>
</dict>
</plist>
XML
  # Zamana duyarlı bildirim: drone uyarısı Odak (Focus) modlarında da görünür.
  cat > ios/Runner/Runner.entitlements <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.usernotifications.time-sensitive</key>
	<true/>
</dict>
</plist>
XML
  # App Store'a yükleme seçenekleri (flutter build ipa --export-options-plist=ios/ExportOptions.plist)
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0"><dict>'
    echo '  <key>method</key><string>app-store-connect</string>'
    echo '  <key>signingStyle</key><string>automatic</string>'
    echo '  <key>uploadSymbols</key><true/>'
    [ -n "${IOS_TEAM_ID:-}" ] && echo "  <key>teamID</key><string>${IOS_TEAM_ID}</string>"
    echo '</dict></plist>'
  } > ios/ExportOptions.plist
fi
if [ -d ios/Runner.xcodeproj ] && command -v ruby >/dev/null && ruby -e "require 'xcodeproj'" 2>/dev/null; then
  ruby tool/ios_project.rb "${IOS_BUNDLE_ID:-}" "${IOS_TEAM_ID:-}"
elif [ -d ios/Runner.xcodeproj ] && [ "$(uname)" = "Darwin" ]; then
  echo "UYARI: xcodeproj gem'i yok (CocoaPods ile gelir: sudo gem install cocoapods). Gizlilik bildirimi Xcode projesine eklenmedi." >&2
fi

PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && [ -x /usr/libexec/PlistBuddy ]; then
  PB=/usr/libexec/PlistBuddy
  $PB -c "Delete :NSMicrophoneUsageDescription" "$PLIST" 2>/dev/null || true
  $PB -c "Add :NSMicrophoneUsageDescription string $MIC_TEXT" "$PLIST"
  $PB -c "Delete :UIBackgroundModes" "$PLIST" 2>/dev/null || true
  $PB -c "Add :UIBackgroundModes array" "$PLIST"
  $PB -c "Add :UIBackgroundModes:0 string audio" "$PLIST"
  $PB -c "Set :CFBundleDisplayName $APP_NAME" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleDisplayName string $APP_NAME" "$PLIST"
  $PB -c "Set :CFBundleName $APP_NAME" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleName string $APP_NAME" "$PLIST"
  $PB -c "Set :ITSAppUsesNonExemptEncryption false" "$PLIST" 2>/dev/null || $PB -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"
  # Desteklenen diller: iOS uygulama dilini (ve Ayarlar'daki dil seçimini) buna göre sunar
  $PB -c "Delete :CFBundleLocalizations" "$PLIST" 2>/dev/null || true
  $PB -c "Add :CFBundleLocalizations array" "$PLIST"
  while read -r L; do
    [ -n "$L" ] && $PB -c "Add :CFBundleLocalizations: string $L" "$PLIST"
  done < tool/platform_l10n/ios/languages.txt
  # iPad: dört yön ve tam ekran zorunlu değil → Bölünmüş Ekran, Slide Over ve Stage Manager desteklenir
  $PB -c "Delete :UIRequiresFullScreen" "$PLIST" 2>/dev/null || true
  $PB -c "Delete :UISupportedInterfaceOrientations~ipad" "$PLIST" 2>/dev/null || true
  $PB -c "Add :UISupportedInterfaceOrientations~ipad array" "$PLIST"
  for o in UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight; do
    $PB -c "Add :UISupportedInterfaceOrientations~ipad: string $o" "$PLIST"
  done
  # iPhone: dikey + iki yatay (ters dikey yok: Apple yönergesi, çentikli telefonlar desteklemez)
  $PB -c "Delete :UISupportedInterfaceOrientations" "$PLIST" 2>/dev/null || true
  $PB -c "Add :UISupportedInterfaceOrientations array" "$PLIST"
  for o in UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight; do
    $PB -c "Add :UISupportedInterfaceOrientations: string $o" "$PLIST"
  done
fi
STORY=ios/Runner/Base.lproj/LaunchScreen.storyboard
if [ -f "$STORY" ]; then
  sed -i.bak -E 's#<color key="backgroundColor"[^/]*/>#<color key="backgroundColor" red="0" green="0" blue="0" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>#' "$STORY" && rm -f "$STORY.bak"
fi
if [ -d ios/Runner/Assets.xcassets/AppIcon.appiconset ] && [ -d assets/icon/ios ]; then
  cp assets/icon/ios/*.png ios/Runner/Assets.xcassets/AppIcon.appiconset/
fi

echo "Platform klasörleri hazır."
