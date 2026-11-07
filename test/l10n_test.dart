// 27 dil: her dilde dört sayfa taşmadan açılır, sağdan sola diller ters döner, biçimler doğru.
import 'package:drone_kulagi/app/monitor.dart';
import 'package:drone_kulagi/app/store.dart';
import 'package:drone_kulagi/l10n/strings.dart';
import 'package:drone_kulagi/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Monitor> _monitor() async {
  SharedPreferences.setMockInitialValues({});
  return Monitor(await AppStore.open());
}

void main() {
  tearDown(() {
    final b = TestWidgetsFlutterBinding.instance;
    final v = b.platformDispatcher.views.first;
    v.resetPhysicalSize();
    v.resetDevicePixelRatio();
    b.platformDispatcher.clearTextScaleFactorTestValue();
    S.current = S.forCode('en');
  });

  test('cihaz dilinden uygulama dili', () {
    Locale r(List<Locale> l) => S.resolve(l, S.supportedLocales);
    expect(r(const [Locale('tr', 'TR')]).languageCode, 'tr');
    expect(r(const [Locale('iw', 'IL')]).languageCode, 'he'); // eski Android İbranice kodu
    expect(r(const [Locale('zh', 'CN')]).scriptCode, 'Hant'); // Çince her zaman Geleneksel
    expect(r(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')]).scriptCode, 'Hant');
    expect(r(const [Locale('nl'), Locale('de')]).languageCode, 'de'); // tercih listesindeki ilk desteklenen
    expect(r(const [Locale('nl')]).languageCode, 'en');
    expect(S.resolve(null, S.supportedLocales).languageCode, 'en');
    expect(kLanguages.length, 27);
    expect(kLanguages.contains('ku'), isFalse);
  });

  test('dile göre biçimler', () {
    final tr = S.forCode('tr');
    expect(tr.upper('ince ayar'), 'İNCE AYAR');
    expect(S.forCode('az').upper('dinlə'), 'DİNLƏ');
    expect(S.forCode('en').upper('fine-tune'), 'FINE-TUNE');
    expect(tr.pct(86), '%86');
    expect(S.forCode('de').pct(86), '86 %');
    expect(S.forCode('en').thousands(6360), '6,360');
    expect(S.forCode('de').thousands(6360), '6.360');
    expect(S.forCode('ru').thousands(6360), '6 360');
    final d = DateTime(2026, 11, 5);
    expect(S.forCode('en').date(d), 'Nov 5');
    expect(tr.date(d), '5 Kas');
    expect(S.forCode('de').date(d), '5. Nov.');
    expect(S.forCode('ja').date(d), '11月5日');
    expect(S.forCode('fi').date(d), '5.11.');
    expect(tr.duration(const Duration(minutes: 2, seconds: 3)), '2 dk 3 sn');
    expect(S.forCode('en').duration(const Duration(hours: 1, minutes: 5)), '1 h 5 min');
    expect(tr.noteDrone(hz: 212), 'Sürekli pervane harmoniği: 212 Hz ve katları.');
    for (final c in kLanguages) {
      final s = S.forCode(c);
      expect(s.isRtl, const {'ar', 'he', 'fa', 'ur'}.contains(c), reason: c);
      expect(s.steadyHum(ignore: 'X').contains('X'), isTrue, reason: c);
      expect(s.tabSettings.length, lessThanOrEqualTo(11), reason: c);
    }
  });

  for (final code in kLanguages) {
    testWidgets('$code: dört sayfa taşmadan açılır', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(320, 640) * 2;
      tester.platformDispatcher.textScaleFactorTestValue = 1.35;
      final m = await _monitor();
      await tester.pumpWidget(DroneKulagiApp(monitor: m, locale: S.localeOf(code)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull, reason: code);
      final t = S.forCode(code);
      expect(S.current.code, code);
      expect(find.text(t.startListening), findsOneWidget, reason: code);
      final dir = Directionality.of(tester.element(find.text(t.startListening)));
      expect(dir, t.isRtl ? TextDirection.rtl : TextDirection.ltr, reason: code);
      for (final tab in [t.tabSpectrum, t.tabLog, t.tabSettings, t.tabListen]) {
        await tester.tap(find.text(tab).last);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: '$code $tab');
      }
      // yatay telefon: yan ray
      tester.view.physicalSize = const Size(844, 390) * 2;
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$code yatay');
    });
  }
}
