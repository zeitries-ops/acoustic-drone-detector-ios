import 'package:flutter/material.dart';

import '../app/monitor.dart';
import '../app/theme.dart';
import '../app/zones.dart';
import '../l10n/strings.dart';
import 'common.dart';

/// Açılışta ortam seçimi: hassasiyet bölgeye göre ayarlanır (Indoors · City · Open area).
///
/// Dışına dokunarak ya da sürükleyerek kapanmaz; seçim bilinçli yapılsın. Geri tuşu kapatır ve o anki
/// ayar kalır. Seçim dokunur dokunmaz uygulanır; zaten seçili bölgeye dokunmak ince ayarı bozmaz.
Future<void> showZonePrompt(BuildContext context, Monitor monitor) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => ZonePrompt(monitor: monitor),
  );
}

class ZonePrompt extends StatelessWidget {
  const ZonePrompt({super.key, required this.monitor});
  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final current = zoneFor(monitor.settings.sensitivity);
        return Container(
          decoration: BoxDecoration(
            color: dk.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: dk.line)),
          ),
          // Buton her zaman görünür; kaydırma yok: içerik sığmazsa üstteki kısım orantılı küçülür.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
                  child: FitPage(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Kicker(t.beforeYouStart),
                      const SizedBox(height: 6),
                      TwoToneTitle(t.whereListening, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        t.promptText(settings: t.tabSettings),
                        style: body(14, dk.muted),
                      ),
                      const SizedBox(height: 14),
                      for (final z in kZones) ...[
                        _ZoneOption(
                          zone: z,
                          selected: identical(z, current),
                          onTap: () {
                            if (!identical(z, current)) monitor.setSensitivity(z.value);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: GradientButton(t.continueButton, onPressed: () => Navigator.of(context).pop()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ZoneOption extends StatelessWidget {
  const _ZoneOption({required this.zone, required this.selected, required this.onTap});
  final EnvZone zone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: '${zone.title(t)}: ${zone.places(t)}',
      child: Material(
        color: selected ? dk.surfaceHi : dk.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? dk.brand : dk.line, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? dk.brand.withValues(alpha: 0.16) : dk.surfaceHi,
                  ),
                  child: Icon(zone.icon, size: 22, color: selected ? dk.brand : dk.muted),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zone.title(t), style: body(16, dk.ink, weight: FontWeight.w600).copyWith(height: 1.2)),
                      Text(zone.places(t), style: small(12, dk.faint)),
                      const SizedBox(height: 4),
                      Text(zone.description(t), style: body(13, dk.muted).copyWith(height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? dk.brand : dk.lineStrong, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: selected
                        ? Container(width: 10, height: 10, decoration: BoxDecoration(color: dk.brand, shape: BoxShape.circle))
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
