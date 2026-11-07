import 'package:flutter/material.dart';

import '../app/brand.dart';
import '../app/monitor.dart';
import '../app/theme.dart';
import '../l10n/strings.dart';
import 'common.dart';

/// Kayıt sayfası: tespitler ve yoksayılan cihaz sesleri. Sayfa kaydırılmaz; kayıt çoksa liste kendi kartında kayar.
class LogPage extends StatelessWidget {
  const LogPage({super.key, required this.monitor, this.trailing});
  final Monitor monitor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final two = useTwoColumns(c.biggest);
      final title = PageTitle(S.of(context).logTitle, trailing: trailing);
      if (two) {
        Widget col(Widget w) => Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Flexible(child: w)]),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  col(LogPanel(monitor: monitor)),
                  const SizedBox(width: 14),
                  col(IgnoredPanel(monitor: monitor)),
                ],
              ),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: 10),
          Flexible(child: LogPanel(monitor: monitor)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: c.maxHeight * 0.36),
            child: IgnoredPanel(monitor: monitor),
          ),
        ],
      );
    });
  }
}

/// Liste kartı: etiket, sağda sayaç; içerik kartın yüksekliğini aşarsa kart içinde kayar.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.label, this.trailing, required this.items, this.footer});
  final String label;
  final Widget? trailing;
  final List<Widget> items;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    return BrandCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Expanded(child: Kicker(label)), if (trailing != null) trailing!]),
          const SizedBox(height: 6),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 6),
              itemCount: items.length,
              separatorBuilder: (_, __) => Container(height: 1, color: dk.line),
              itemBuilder: (_, i) => items[i],
            ),
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// "Bu sesi yoksay" ile kaydedilen cihaz sesleri.
class IgnoredPanel extends StatelessWidget {
  const IgnoredPanel({super.key, required this.monitor});
  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    final list = monitor.ignored;
    return _ListCard(
      label: t.ignoredTitle,
      trailing: list.isEmpty ? null : Text('${list.length}', style: small(12, dk.faint)),
      items: [
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              t.ignoredEmpty(ignore: t.ignoreSound, listen: t.tabListen),
              style: body(13.5, dk.muted).copyWith(height: 1.4),
            ),
          )
        else
          for (final s in list)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.ignoredItem(hz: s.f0.round()),
                            style: body(15, dk.ink, weight: FontWeight.w600).copyWith(fontFeatures: tabular)),
                        Text(
                          [
                            if (s.mains > 0.5) t.mainsLocked,
                            if (s.jitter.isFinite) s.jitter < 0.0015 ? t.steadySpeed : t.varyingSpeed,
                            t.date(DateTime.fromMillisecondsSinceEpoch(s.createdMs)),
                          ].join(' · '),
                          style: small(11.5, dk.faint),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: t.removeFromList,
                    icon: Icon(Icons.close_rounded, color: dk.muted),
                    onPressed: () => monitor.removeIgnored(s),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Tespit kaydı.
class LogPanel extends StatelessWidget {
  const LogPanel({super.key, required this.monitor});
  final Monitor monitor;

  Future<void> _confirmClear(BuildContext context) async {
    final dk = context.dk;
    final t = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.clearLogTitle, style: display(22, dk.ink)),
        content: Text(t.clearLogBody, style: body(15, dk.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.upper(t.cancel))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t.upper(t.clear), style: TextStyle(color: dk.alert))),
        ],
      ),
    );
    if (ok == true) monitor.clearEvents();
  }

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    final events = monitor.events;
    final shown = events.take(50).toList();
    return _ListCard(
      label: t.detections,
      trailing: events.isEmpty ? null : Text('${two(shown.length)} / ${two(events.length)}', style: small(12, dk.faint)),
      footer: events.isEmpty
          ? null
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: LinkText(t.clearLog, onTap: () => _confirmClear(context), color: dk.muted),
            ),
      items: [
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history_rounded, color: dk.faint, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.logEmpty,
                      style: body(13.5, dk.muted).copyWith(height: 1.4)),
                ),
              ],
            ),
          )
        else
          for (final e in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t.date(DateTime.fromMillisecondsSinceEpoch(e.startMs))}  ${fmtClock(DateTime.fromMillisecondsSinceEpoch(e.startMs))}',
                          style: small(13.5, dk.ink, weight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tag(e.ignored ? t.tagIgnored : t.tagDrone, e.ignored ? dk.purple : dk.alert),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${e.duration != null ? t.duration(e.duration!) : t.ongoing} · ${t.ltr('${e.f0.round()} Hz')} · ${t.peak(v: e.peak.round())}',
                    style: small(11.5, dk.faint),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Ayarlar sayfasının altı: "Nasıl çalışır" (alt sayfa), lisanslar ve sürüm.
class AboutLinks extends StatelessWidget {
  const AboutLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 18,
      children: [
        LinkText(t.howItWorks, onTap: () => showAboutSheet(context)),
        LinkText(t.licenses, onTap: () => showLicenses(context), color: dk.muted),
        Text('v$kAppVersion · ${t.noAudioRecorded}', style: small(11, dk.faint)),
      ],
    );
  }
}

void showLicenses(BuildContext context) =>
    showLicensePage(context: context, applicationName: kAppName, applicationVersion: kAppVersion);

/// "Nasıl çalışır": yöntem, gizlilik, sınırlar. Kaydırılmaz; sığmazsa orantılı küçülür.
Future<void> showAboutSheet(BuildContext context) {
  final dk = context.dk;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: dk.surface,
    constraints: const BoxConstraints(maxWidth: 640),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: dk.line),
    ),
    builder: (c) => const AboutSheet(),
  );
}

class AboutSheet extends StatelessWidget {
  const AboutSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    Widget h(String text) => Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Kicker(text));
    final b = body(13.5, dk.muted).copyWith(height: 1.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: FitPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TwoToneTitle(t.howItWorks, size: 24),
                  const SizedBox(height: 8),
                  Text(t.aboutIntro, style: b),
                  h(t.aboutFanTitle),
                  Text(t.aboutFan, style: b),
                  h(t.aboutYamTitle),
                  Text(t.aboutYam, style: b),
                  h(t.aboutPrivacyTitle),
                  Text(t.aboutPrivacy, style: b),
                  h(t.aboutLimitsTitle),
                  Text(t.aboutLimits, style: b),
                  const SizedBox(height: 10),
                  Text('$kAppName v$kAppVersion · ${t.aboutFooter}', style: small(11, dk.faint)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Flexible(child: LinkText(t.licenses, onTap: () => showLicenses(context), color: dk.muted)),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(t.close)),
            ],
          ),
        ],
      ),
    );
  }
}
