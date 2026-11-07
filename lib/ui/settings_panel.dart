import 'package:flutter/material.dart';

import '../app/monitor.dart';
import '../app/theme.dart';
import '../app/zones.dart';
import '../core/detector.dart';
import '../l10n/strings.dart';
import 'common.dart';
import 'info_panels.dart';

/// Ayarlar sayfası: ortam (hassasiyet), aranan drone tipi, uyarılar; altta "Nasıl çalışır" ve lisanslar.
/// Kaydırılmaz: dar ekranda tek sütun, yatay ekranda iki sütun; sığmazsa orantılı küçülür.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.monitor, this.trailing});
  final Monitor monitor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final two = useTwoColumns(c.biggest);
      final env = _EnvironmentCard(monitor: monitor);
      final preset = _PresetCard(monitor: monitor);
      final alerts = _AlertsCard(monitor: monitor);
      const about = AboutLinks();
      const gap = SizedBox(height: 12);
      return FitPage(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: two ? 1100 : 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageTitle(S.of(context).settingsTitle, trailing: trailing),
                const SizedBox(height: 10),
                if (two)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: env),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [preset, gap, alerts, const SizedBox(height: 4), about],
                        ),
                      ),
                    ],
                  )
                else ...[env, gap, preset, gap, alerts, const SizedBox(height: 4), about],
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Küçük kart: üstte marka renginde etiket.
class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BrandCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(label),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  const _EnvironmentCard({required this.monitor});
  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    final m = monitor;
    final s = m.settings.sensitivity;
    final zone = zoneFor(s);
    return _MiniCard(
      label: t.whereListening,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < kZones.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _ZoneTile(
                    zone: kZones[i],
                    selected: identical(kZones[i], zone),
                    onTap: () => m.setSensitivity(kZones[i].value),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(zone.description(t), style: body(13, dk.muted).copyWith(height: 1.4)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Eyebrow(t.fineTune)),
            Text('${(s * 100).round()}', style: small(12, dk.brand)),
          ],
        ),
        SizedBox(
          height: 36,
          child: Slider(
            value: s,
            divisions: 20,
            label: '${zone.title(t)} · ${(s * 100).round()}',
            onChanged: m.setSensitivity,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.arrow_back_rounded, size: 12, color: dk.faint),
            const SizedBox(width: 4),
            Expanded(child: Text(t.fewerFalseAlarms, style: small(10.5, dk.faint))),
            const SizedBox(width: 12),
            Expanded(child: Text(t.longerRange, style: small(10.5, dk.faint), textAlign: TextAlign.end)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 12, color: dk.faint),
          ],
        ),
      ],
    );
  }
}

class _ZoneTile extends StatelessWidget {
  const _ZoneTile({required this.zone, required this.selected, required this.onTap});
  final EnvZone zone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: '${zone.title(t)}: ${zone.places(t)}',
      child: Material(
        color: selected ? dk.surfaceHi : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? dk.brand : dk.line, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(zone.icon, size: 22, color: selected ? dk.brand : dk.muted),
                const SizedBox(height: 6),
                TileTitle(zone.title(t), style: body(15, selected ? dk.ink : dk.muted, weight: FontWeight.w600).copyWith(height: 1.15)),
                const SizedBox(height: 4),
                Text(zone.places(t), style: small(10.5, dk.faint), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.monitor});
  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    final m = monitor;
    final items = [
      (DronePreset.multi, t.presetMulti, t.ltr('90–450 Hz'), t.presetMultiText),
      (DronePreset.fpv, t.presetFpv, t.ltr('180–900 Hz'), t.presetFpvText),
      (DronePreset.wide, t.presetWide, t.ltr('70–900 Hz'), t.presetWideText),
    ];
    final sel = items.firstWhere((e) => e.$1 == m.settings.preset, orElse: () => items.first);
    return _MiniCard(
      label: t.droneType,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, (p, title, range, _)) in items.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceTile(
                    selected: p == sel.$1,
                    title: title,
                    subtitle: range,
                    onTap: () => m.setPreset(p),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(sel.$4, style: small(12, dk.muted)),
      ],
    );
  }
}

/// Seçim kutucuğu (drone tipi): başlık ve küçük alt satır.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.selected, required this.title, required this.subtitle, required this.onTap});
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? dk.surfaceHi : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? dk.brand : dk.line, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TileTitle(title, style: body(14, selected ? dk.ink : dk.muted, weight: FontWeight.w600).copyWith(height: 1.15)),
                const SizedBox(height: 3),
                Text(subtitle, style: small(10.5, selected ? dk.brand : dk.faint), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard({required this.monitor});
  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    final s = monitor.settings;
    return _MiniCard(
      label: t.alerts,
      children: [
        // dar kartta alt alta: uzun etiketler (ör. "Benachrichtigungen") sığsın
        LayoutBuilder(builder: (context, c) {
          final a = _Toggle(label: t.notifications, value: s.notify, onChanged: monitor.setNotify);
          final b = _Toggle(label: t.vibrate, value: s.vibrate, onChanged: monitor.setVibrate);
          return c.maxWidth >= 460
              ? Row(children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 8), b]);
        }),
        const SizedBox(height: 8),
        Text(t.alertsHint, style: small(12, dk.muted)),
      ],
    );
  }
}

/// Etiketli anahtar: tüm kutucuk dokunulabilir.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    return MergeSemantics(
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: dk.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 6, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: body(14, dk.ink, weight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
