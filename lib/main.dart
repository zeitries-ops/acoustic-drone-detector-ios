import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/brand.dart';
import 'app/monitor.dart';
import 'app/store.dart';
import 'app/theme.dart';
import 'l10n/strings.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_assetLicenses);
  final store = await AppStore.open();
  final monitor = Monitor(store);
  runApp(DroneKulagiApp(monitor: monitor));
  await monitor.init();
}

/// Pakete gömülü model ve yazı tiplerinin lisansları (Ayarlar → lisanslar ekranında görünür).
Stream<LicenseEntry> _assetLicenses() async* {
  for (final (pkg, path) in const [
    ('YAMNet (Google)', 'assets/models/YAMNET_LICENSE.txt'),
    ('Poppins', 'assets/fonts/OFL-Poppins.txt'),
  ]) {
    yield LicenseEntryWithLineBreaks([pkg], await rootBundle.loadString(path));
  }
}

class DroneKulagiApp extends StatelessWidget {
  const DroneKulagiApp({super.key, required this.monitor, this.locale});

  final Monitor monitor;

  /// Testler için sabit dil; uygulamada cihaz dili kullanılır.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.dark,
      locale: locale,
      supportedLocales: S.supportedLocales,
      localeListResolutionCallback: S.resolve,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.35,
        child: child ?? const SizedBox.shrink(),
      ),
      home: HomePage(monitor: monitor),
    );
  }
}
