import 'package:drone_kulagi/app/brand.dart';
import 'package:drone_kulagi/app/monitor.dart';
import 'package:drone_kulagi/app/store.dart';
import 'package:drone_kulagi/main.dart';
import 'package:drone_kulagi/app/zones.dart';
import 'package:drone_kulagi/ui/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Monitor> _monitor() async {
  SharedPreferences.setMockInitialValues({});
  final store = await AppStore.open();
  return Monitor(store);
}

Future<void> _pumpAt(WidgetTester tester, Size logical, {double textScale = 1.0}) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = logical * 2.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  final m = await _monitor();
  await tester.pumpWidget(DroneKulagiApp(monitor: m));
  await tester.pump(const Duration(milliseconds: 100));
}

/// İki tonlu başlıklar iki ayrı metne bölünür; başlığı bileşenin kendisinden bul.
Finder _title(String t) => find.byWidgetPredicate((w) => w is TwoToneTitle && w.text == t);

void main() {
  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  // Ekran boyutları: küçük telefon, büyük telefon, yatay telefon, tablet dikey/yatay
  const sizes = <String, Size>{
    'küçük telefon': Size(320, 640),
    'telefon': Size(390, 844),
    'yatay telefon': Size(844, 390),
    'tablet dikey': Size(820, 1180),
    'tablet yatay': Size(1366, 1024),
  };

  for (final e in sizes.entries) {
    testWidgets('${e.key} (${e.value.width.toInt()}×${e.value.height.toInt()}) taşmadan çizilir', (tester) async {
      await _pumpAt(tester, e.value);
      expect(tester.takeException(), isNull);
      expect(find.text(kAppName), findsWidgets);
      expect(find.text('Start listening'), findsOneWidget);
    });
  }

  testWidgets('büyük yazı boyutunda (1.35×) küçük telefonda dört sekmede de taşma yok', (tester) async {
    await _pumpAt(tester, const Size(320, 640), textScale: 2.0);
    expect(tester.takeException(), isNull);
    for (final tab in ['Spectrum', 'Log', 'Settings', 'Listen']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('dikey telefonda alt sekmeler, yatayda ve tablette yan ray', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await _pumpAt(tester, const Size(844, 390));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    await _pumpAt(tester, const Size(1366, 1024));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiçbir sayfa kaydırılmaz (kayıt listesi yalnızca kendi kartında kayar)', (tester) async {
    for (final size in const [Size(390, 844), Size(844, 390), Size(1366, 1024)]) {
      await _pumpAt(tester, size);
      for (final tab in ['Listen', 'Spectrum', 'Settings']) {
        await tester.tap(find.text(tab).last);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(Scrollable), findsNothing, reason: '$size $tab');
      }
      await tester.tap(find.text('Log').last);
      await tester.pump(const Duration(milliseconds: 400));
      // yalnızca iki kartın iç listeleri
      expect(find.byType(Scrollable), findsNWidgets(2), reason: '$size Log');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('telefonda Spektrum, Ayarlar ve Kayıt sekmeleri açılır', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    await tester.tap(find.text('Spectrum').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_title('Live spectrum'), findsOneWidget);
    expect(find.text('Drone'), findsOneWidget); // renk açıklaması
    await tester.tap(find.text('Settings').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Indoors'), findsOneWidget);
    expect(find.text('Open area'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Multicopter'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('How it works'));
    await tester.pumpAndSettle();
    expect(_title('How it works'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('DETECTIONS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ortam bölgesine dokununca hassasiyet değişir', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    await tester.tap(find.text('Settings').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Open area'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('80'), findsOneWidget);
    await tester.tap(find.text('Indoors'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('20'), findsOneWidget);
  });

  test('biçimler İngilizce', () {
    expect(upper('Fine-tune'), 'FINE-TUNE');
    expect(fmtThousands(6360), '6,360');
    expect(fmtDate(DateTime(2026, 11, 5)), 'Nov 5');
    expect(fmtDuration(const Duration(minutes: 2, seconds: 3)), '2 min 3 s');
  });

  test('ortam bölgeleri hassasiyet ölçeğini kapsar', () {
    expect(zoneFor(0).id, 'indoor');
    expect(zoneFor(0.5).id, 'city');
    expect(zoneFor(1).id, 'open');
    for (final z in kZones) {
      expect(zoneFor(z.value).id, z.id);
    }
  });
}
