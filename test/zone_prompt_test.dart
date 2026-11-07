import 'package:drone_kulagi/app/monitor.dart';
import 'package:drone_kulagi/app/store.dart';
import 'package:drone_kulagi/main.dart';
import 'package:drone_kulagi/ui/common.dart';
import 'package:drone_kulagi/ui/zone_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Monitor> _monitor({double? sensitivity}) async {
  SharedPreferences.setMockInitialValues({});
  final m = Monitor(await AppStore.open());
  if (sensitivity != null) m.setSensitivity(sensitivity);
  return m;
}

/// Uygulamayı başlatır ve açılıştaki init()'i (yerel katman yokken hızla biter) çalıştırır.
Future<void> _launch(WidgetTester tester, Monitor m, {Size size = const Size(390, 844)}) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = size * 2.0;
  await tester.pumpWidget(DroneKulagiApp(monitor: m));
  await tester.runAsync(m.init);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Finder get _prompt => find.byType(ZonePrompt);

void main() {
  tearDown(() {
    final v = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    v.resetPhysicalSize();
    v.resetDevicePixelRatio();
  });

  testWidgets('soğuk açılışta ortam sorulur, seçim hemen uygulanır', (tester) async {
    final m = await _monitor();
    await _launch(tester, m);
    expect(_prompt, findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is TwoToneTitle && w.text == 'Where are you listening?'), findsOneWidget);

    await tester.tap(find.descendant(of: _prompt, matching: find.text('Open area')));
    await tester.pump();
    expect(m.settings.sensitivity, 0.8);
    expect(m.detector.sensitivity, 0.8);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(_prompt, findsNothing);
    expect(m.zoneAskedThisLaunch, isTrue);
  });

  testWidgets('arka plana atıp geri açınca yeniden sorulmaz', (tester) async {
    final m = await _monitor();
    await _launch(tester, m);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(s);
      await tester.pump();
    }
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(_prompt, findsNothing);
  });

  testWidgets('zaten seçili bölgeye dokunmak ince ayarı bozmaz', (tester) async {
    final m = await _monitor(sensitivity: 0.45); // City bölgesinde ince ayar
    await _launch(tester, m);
    await tester.tap(find.descendant(of: _prompt, matching: find.text('City')));
    await tester.pump();
    expect(m.settings.sensitivity, 0.45);
  });

  testWidgets('dinleme sürerken açılırsa sorulmaz', (tester) async {
    final m = await _monitor();
    m.listening = true; // ör. drone bildirimine dokunarak açıldı
    await _launch(tester, m);
    expect(_prompt, findsNothing);
  });

  testWidgets('büyük yazı ve küçük telefonda taşmaz', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.35;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final m = await _monitor();
    await _launch(tester, m, size: const Size(320, 640));
    expect(_prompt, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(_prompt, findsNothing);
  });
}
