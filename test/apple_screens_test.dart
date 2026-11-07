// Apple cihazlarının ekran boyutları ve güvenli alanlarıyla düzen testi: taşma (overflow) ya da hata olmamalı.
import 'package:drone_kulagi/app/monitor.dart';
import 'package:drone_kulagi/app/store.dart';
import 'package:drone_kulagi/main.dart';
import 'package:drone_kulagi/ui/home_page.dart';
import 'package:drone_kulagi/ui/zone_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Device {
  const Device(this.name, this.w, this.h, {this.top = 0, this.bottom = 0, this.left = 0, this.right = 0});
  final String name;
  final double w, h, top, bottom, left, right;
}

/// Mantıksal nokta (pt) ve güvenli alanlar.
const devices = <Device>[
  Device('iPhone SE', 375, 667, top: 20),
  Device('iPhone SE yatay', 667, 375),
  Device('iPhone 13 mini', 375, 812, top: 50, bottom: 34),
  Device('iPhone 16', 393, 852, top: 59, bottom: 34),
  Device('iPhone 16 Pro', 402, 874, top: 62, bottom: 34),
  Device('iPhone 16 Plus', 430, 932, top: 59, bottom: 34),
  Device('iPhone 16 Pro Max', 440, 956, top: 62, bottom: 34),
  Device('iPhone 16 Pro Max yatay', 956, 440, left: 62, right: 62, bottom: 21),
  Device('iPhone 16 yatay', 852, 393, left: 59, right: 59, bottom: 21),
  Device('iPad mini', 744, 1133, top: 24, bottom: 20),
  Device('iPad mini yatay', 1133, 744, top: 24, bottom: 20),
  Device('iPad 11"', 834, 1194, top: 24, bottom: 20),
  Device('iPad 11" yatay', 1194, 834, top: 24, bottom: 20),
  Device('iPad 13"', 1032, 1376, top: 24, bottom: 20),
  Device('iPad 13" yatay', 1376, 1032, top: 24, bottom: 20),
  Device('Slide Over', 320, 1032, top: 24, bottom: 20),
  Device('Bölünmüş ekran 1/3', 375, 1032, top: 24, bottom: 20),
  Device('Bölünmüş ekran 1/2 (11" yatay)', 590, 834, top: 24, bottom: 20),
  Device('Bölünmüş ekran 1/2 (13" yatay)', 678, 1032, top: 24, bottom: 20),
  Device('Bölünmüş ekran 2/3 (13" dikey)', 694, 1376, top: 24, bottom: 20),
  Device('Bölünmüş ekran 2/3 (13" yatay)', 981, 1032, top: 24, bottom: 20),
  Device('Stage Manager küçük pencere', 600, 420),
];

Future<Monitor> _monitor() async {
  SharedPreferences.setMockInitialValues({});
  return Monitor(await AppStore.open());
}

void _setDevice(WidgetTester tester, Device d, {double scale = 1}) {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(d.w * dpr, d.h * dpr);
  final p = FakeViewPadding(left: d.left * dpr, top: d.top * dpr, right: d.right * dpr, bottom: d.bottom * dpr);
  tester.view.padding = p;
  tester.view.viewPadding = p;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
}

void main() {
  tearDown(() {
    final b = TestWidgetsFlutterBinding.instance;
    final v = b.platformDispatcher.views.first;
    v.resetPhysicalSize();
    v.resetDevicePixelRatio();
    v.resetPadding();
    v.resetViewPadding();
    b.platformDispatcher.clearTextScaleFactorTestValue();
  });

  for (final d in devices) {
    for (final scale in const [1.0, 1.35]) {
      testWidgets('${d.name} · yazı ×$scale: tüm bölümler taşmadan açılır', (tester) async {
        _setDevice(tester, d, scale: scale);
        final m = await _monitor();
        await tester.pumpWidget(DroneKulagiApp(monitor: m));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);

        expect(find.byType(HomePage.useRail(Size(d.w, d.h)) ? NavigationRail : NavigationBar), findsOneWidget);
        // dört sayfa: hiçbiri kaydırılmaz, taşma olmaz (kayıt listeleri yalnızca kendi kartlarında kayar)
        for (final tab in ['Spectrum', 'Log', 'Settings', 'Listen']) {
          await tester.tap(find.text(tab).last);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: '${d.name} $tab');
          if (tab != 'Log') expect(find.byType(Scrollable), findsNothing, reason: '${d.name} $tab kaydırılmamalı');
        }
      });
    }

    testWidgets('${d.name}: açılıştaki ortam sorusu sığar ve kapanır', (tester) async {
      _setDevice(tester, d, scale: 1.35);
      final m = await _monitor();
      await tester.pumpWidget(DroneKulagiApp(monitor: m));
      await tester.runAsync(m.init);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(ZonePrompt), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(ZonePrompt), findsNothing);
    });
  }
}
