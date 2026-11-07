import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/monitor.dart';
import '../app/theme.dart';
import '../core/detector.dart';
import '../l10n/strings.dart';
import 'common.dart';
import 'info_panels.dart';
import 'live_panel.dart';
import 'settings_panel.dart';
import 'spectrum_page.dart';
import 'zone_prompt.dart';

/// Ana ekran: dört sayfa — Dinle · Spektrum · Kayıt · Ayarlar. Hiçbir sayfa kaydırılmaz.
///  - Dikey telefon / dar pencere: altta sekme çubuğu.
///  - Yatay telefon, iPad, geniş pencere: yanda gezinme rayı.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.monitor});

  final Monitor monitor;

  static const int listenTab = 0, spectrumTab = 1, logTab = 2, settingsTab = 3;

  /// Yanda ray: geniş ekran ya da yatay ve yeterince geniş pencere.
  static bool useRail(Size s) => s.width >= 720 || (s.width > s.height && s.width >= 560);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = HomePage.listenTab;
  int _seenEvents = 0;

  Monitor get m => widget.monitor;

  @override
  void initState() {
    super.initState();
    _seenEvents = m.events.length;
    _askZoneOnLaunch();
  }

  /// Soğuk açılışta ortam seçimini sor (ilk izlenim hassasiyete bağlı). Arka plandan dönüşte bu durum
  /// nesnesi ve Monitor aynı kaldığı için sorulmaz; dinleme zaten sürüyorsa da araya girilmez.
  Future<void> _askZoneOnLaunch() async {
    await m.ready;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || m.zoneAskedThisLaunch || m.listening) return;
    m.zoneAskedThisLaunch = true;
    await showZonePrompt(context, m);
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: dk.bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ListenableBuilder(
        listenable: m,
        builder: (context, _) {
          final size = MediaQuery.sizeOf(context);
          final rail = HomePage.useRail(size);
          if (_tab == HomePage.logTab) _seenEvents = m.events.length;
          final unseen = (m.events.length - _seenEvents).clamp(0, 99);
          final items = _destinations(unseen);
          final page = _page(context);
          return PopScope(
            canPop: !m.listening && _tab == HomePage.listenTab,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_tab != HomePage.listenTab) {
                setState(() => _tab = HomePage.listenTab);
              } else if (m.listening) {
                m.moveToBackground();
              }
            },
            child: Scaffold(
              body: SafeArea(
                bottom: rail,
                child: rail
                    ? Row(
                        children: [
                          _Rail(selected: _tab, items: items, onSelect: _select, showLogo: size.height >= 520),
                          VerticalDivider(width: 1, thickness: 1, color: dk.line),
                          Expanded(child: _padded(page, size.width >= 1000 ? 28 : 18, top: 14)),
                        ],
                      )
                    : _padded(page, 16, top: 10),
              ),
              bottomNavigationBar: rail
                  ? null
                  : Container(
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: dk.line))),
                      child: NavigationBar(
                        selectedIndex: _tab,
                        onDestinationSelected: _select,
                        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                        destinations: [
                          for (final d in items) NavigationDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: d.label),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  void _select(int i) => setState(() => _tab = i);

  Widget _padded(Widget child, double gutter, {required double top}) =>
      Padding(padding: EdgeInsets.fromLTRB(gutter, top, gutter, 12), child: child);

  List<_Dest> _destinations(int unseen) {
    final t = S.of(context);
    return [
        _Dest(
          t.tabListen,
          Icon(m.listening ? Icons.graphic_eq_rounded : Icons.hearing_outlined),
          Icon(m.listening ? Icons.graphic_eq_rounded : Icons.hearing_rounded),
        ),
        _Dest(t.tabSpectrum, const Icon(Icons.ssid_chart_rounded), const Icon(Icons.ssid_chart_rounded)),
        _Dest(
          t.tabLog,
          Badge(isLabelVisible: unseen > 0, label: Text('$unseen'), child: const Icon(Icons.history_rounded)),
          Badge(isLabelVisible: unseen > 0, label: Text('$unseen'), child: const Icon(Icons.history_rounded)),
        ),
        _Dest(t.tabSettings, const Icon(Icons.tune_rounded), const Icon(Icons.tune_rounded)),
      ];
  }

  Widget _page(BuildContext context) {
    final pill = StatusPill(monitor: m);
    switch (_tab) {
      case HomePage.spectrumTab:
        return SpectrumPage(key: const ValueKey('page-spectrum'), monitor: m, trailing: pill);
      case HomePage.logTab:
        return LogPage(key: const ValueKey('page-log'), monitor: m, trailing: pill);
      case HomePage.settingsTab:
        return SettingsPage(key: const ValueKey('page-settings'), monitor: m, trailing: pill);
      default:
        return ListenPage(key: const ValueKey('page-listen'), monitor: m);
    }
  }
}

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final Widget icon;
  final Widget selectedIcon;
}

/// Yan gezinme rayı (yatay telefon, iPad). Sağdan sola dillerde kendiliğinden sağa geçer.
class _Rail extends StatelessWidget {
  const _Rail({required this.selected, required this.items, required this.onSelect, required this.showLogo});
  final int selected;
  final List<_Dest> items;
  final ValueChanged<int> onSelect;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    return NavigationRail(
      selectedIndex: selected,
      onDestinationSelected: onSelect,
      labelType: NavigationRailLabelType.all,
      minWidth: 84,
      groupAlignment: -0.85,
      leading: showLogo
          ? Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 10),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dk.ink, width: 1.4)),
                child: Icon(Icons.hearing_rounded, color: dk.accent, size: 22),
              ),
            )
          : null,
      destinations: [
        for (final d in items)
          NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label)),
      ],
    );
  }
}

/// Sayfa başlıklarının sağındaki durum hapı: dinlerken "Listening", drone varken kırmızı "Drone".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.monitor});
  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    if (!monitor.listening) return const SizedBox.shrink();
    final drone = monitor.last?.state == DetectorState.drone;
    final c = drone ? dk.alert : dk.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(drone ? S.of(context).pillDrone : S.of(context).pillListening, style: small(12, c, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}
