import 'package:flutter/material.dart';

import '../app/brand.dart';
import '../app/monitor.dart';
import '../app/theme.dart';
import '../core/detector.dart';
import '../l10n/strings.dart';
import 'common.dart';

/// Dinle sayfası: durum, düğmeler ve gerekçeler. Kaydırılmaz; sığmazsa orantılı küçülür.
/// Düzen ve renkler ilk v2'deki gibidir; yalnızca yazı tipi (Poppins) yenidir. Spektrum ayrı sayfada.
class ListenPage extends StatelessWidget {
  const ListenPage({super.key, required this.monitor});

  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final two = useTwoColumns(c.biggest); // durum solda, ölçümler sağda
      return FitPage(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: two ? 1100 : 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ListenHeader(),
                SizedBox(height: two ? 10 : 14),
                LivePanel(monitor: monitor, twoColumn: two),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Dinle bölümünün v2.0'daki başlığı.
class _ListenHeader extends StatelessWidget {
  const _ListenHeader();

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dk.ink, width: 1.6)),
          child: Icon(Icons.hearing_rounded, color: dk.accent, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(kAppName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
              ),
              Text(t.tagline,
                  style: TextStyle(color: dk.muted, fontSize: 13.5), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

/// Canlı dinleme kartı: durum kutusu, düğmeler, uyarı mesajları.
class LivePanel extends StatelessWidget {
  const LivePanel({super.key, required this.monitor, this.twoColumn = false});

  final Monitor monitor;
  final bool twoColumn;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    final m = monitor;
    final r = m.last;
    final agg = r?.agg;
    final hasCandidate = m.listening && agg != null && agg.nDet >= 3;
    return _Card(
      children: [
        _StatusBox(monitor: m, twoColumn: twoColumn),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: m.starting ? null : m.toggle,
              icon: Icon(m.listening ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(m.starting ? t.startingButton : (m.listening ? t.stopListening : t.startListening)),
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 52),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 16, fontWeight: FontWeight.w600),
                backgroundColor: m.listening ? dk.lineStrong : dk.accent,
                foregroundColor: m.listening ? dk.ink : dk.accentInk,
              ),
            ),
            if (hasCandidate)
              OutlinedButton.icon(
                onPressed: m.ignoreCurrent,
                icon: const Icon(Icons.volume_off_rounded, size: 20),
                label: Text(t.ignoreSound),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  foregroundColor: dk.ink,
                  side: BorderSide(color: dk.warn),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            if (m.listening)
              TextButton.icon(
                onPressed: m.recalibrate,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(t.relearn),
                style: _textButton(dk),
              ),
          ],
        ),
        if (m.error != null) ...[
          const SizedBox(height: 10),
          _Message(text: m.error!, color: dk.alert, action: (m.permissions?.microphoneBlocked ?? false) ? (t.openSettings, m.openSettings) : null),
        ],
        if (m.notice != null) ...[
          const SizedBox(height: 10),
          _Message(text: m.notice!, color: dk.warn),
        ],
        if (m.listening && m.settings.notify && m.permissions != null && !m.permissions!.notifications) ...[
          const SizedBox(height: 10),
          _Message(
            text: t.notificationsOff,
            color: dk.warn,
            action: (t.openSettings, m.openSettings),
          ),
        ],
      ],
    );
  }
}

ButtonStyle _textButton(DkColors dk) => TextButton.styleFrom(
      minimumSize: const Size(64, 48),
      foregroundColor: dk.accent,
      textStyle: const TextStyle(fontFamily: kFont, fontFamilyFallback: kFontFallback, fontSize: 14, fontWeight: FontWeight.w500),
    );

/// v2.0'daki düz kart.
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    return Material(
      color: dk.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: dk.line)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.color, this.action});
  final String text;
  final Color color;
  final (String, Future<void> Function())? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: TextStyle(color: context.dk.ink, fontSize: 14))),
          if (action != null) TextButton(onPressed: action!.$2, style: _textButton(context.dk), child: Text(action!.$1)),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.monitor, this.twoColumn = false});
  final Monitor monitor;
  final bool twoColumn;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    final m = monitor;
    final r = m.listening ? m.last : null;
    final state = r?.state;
    final agg = r?.agg;

    Color bg, lamp;
    switch (state) {
      case DetectorState.clear:
        bg = dk.okSoft;
        lamp = dk.ok;
      case DetectorState.suspect:
        bg = dk.warnSoft;
        lamp = dk.warn;
      case DetectorState.drone:
        bg = dk.alertSoft;
        lamp = dk.alert;
      case DetectorState.calibrating:
        bg = dk.bg;
        lamp = dk.accent;
      case null:
        bg = dk.bg;
        lamp = dk.muted;
    }

    final word = !m.listening ? (m.starting ? t.stateStarting : t.stateNotListening) : (r == null ? t.stateLearning : stateWord(r.state, t));
    final hasCandidate = agg != null && agg.nDet >= 3;
    String note;
    if (!m.listening) {
      note = t.noteIdle;
    } else if (r == null || state == DetectorState.calibrating) {
      note = t.noteCalibrating(percent: t.pct((r?.calibProgress ?? 0) * 100));
    } else if (r.ignoredHit) {
      note = t.noteIgnored;
    } else if (state == DetectorState.drone) {
      note = t.noteDrone(hz: _f0(r).round());
    } else if (state == DetectorState.suspect) {
      note = t.noteSuspect;
    } else if (r.veto) {
      note = t.noteVeto;
    } else if (hasCandidate) {
      note = t.noteDeviceLike;
    } else {
      note = t.noteNone;
    }

    final conf = (r?.conf ?? 0.0).clamp(0.0, 1.0);
    final det = m.detector;

    final main = <Widget>[
      Row(
        children: [
          _Lamp(color: lamp, pulse: state == DetectorState.drone),
          const SizedBox(width: 14),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                word,
                style: TextStyle(
                  fontSize: 40,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: state == DetectorState.drone ? dk.alert : dk.ink,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(note, style: TextStyle(fontSize: 15, color: state == null ? dk.muted : dk.ink)),
      const SizedBox(height: 14),
      _ConfidenceBar(value: conf, suspect: det.suspectOn, alarm: det.alarmOn, color: lamp),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(child: Eyebrow(t.droneProbability)),
          Text(t.pct(conf * 100), style: small(12.5, dk.muted).copyWith(fontFeatures: tabular)),
        ],
      ),
    ];
    // ipuçları ve uyarı: tek sütunda ölçümlerin altında; iki sütunda iki sütunun altında tam genişlik
    final extra = <Widget>[
      if (hasCandidate && r?.reasons != null) ...[
        const SizedBox(height: 14),
        _ReasonChips(reasons: r!.reasons!),
      ],
      if (state == DetectorState.drone && (agg?.steady ?? false) && m.steadyFor > 30) ...[
        const SizedBox(height: 10),
        Text(
          t.steadyHum(ignore: t.ignoreSound),
          style: TextStyle(color: dk.warn, fontSize: 14),
        ),
      ],
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: state == DetectorState.drone ? dk.alert : Colors.transparent, width: 1.5),
      ),
      child: twoColumn
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: main)),
                    const SizedBox(width: 20),
                    Expanded(child: _Readouts(monitor: m)),
                  ],
                ),
                ...extra,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...main, const SizedBox(height: 14), _Readouts(monitor: m), ...extra],
            ),
    );
  }

  static double _f0(DetectorResult r) => (r.agg?.f0p ?? 0) > 0 ? r.agg!.f0p : r.f0;
}

class _Lamp extends StatefulWidget {
  const _Lamp({required this.color, required this.pulse});
  final Color color;
  final bool pulse;

  @override
  State<_Lamp> createState() => _LampState();
}

class _LampState extends State<_Lamp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _Lamp old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (widget.pulse && !reduce) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final spread = 4 + 6 * _c.value;
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.28 * (1 - _c.value * 0.6)), spreadRadius: spread)],
          ),
        );
      },
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.value, required this.suspect, required this.alarm, required this.color});
  final double value, suspect, alarm;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Container(height: 10, decoration: BoxDecoration(color: dk.ink.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: w * value,
                height: 10,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
              ),
              for (final x in [suspect, alarm])
                PositionedDirectional(
                  start: (w * x - 1).clamp(0.0, w - 2),
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: dk.ink.withValues(alpha: 0.55)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Readouts extends StatelessWidget {
  const _Readouts({required this.monitor});
  final Monitor monitor;

  @override
  Widget build(BuildContext context) {
    final t = S.of(context);
    final m = monitor;
    final r = m.listening ? m.last : null;
    final active = r != null && r.agg != null && (r.state == DetectorState.suspect || r.state == DetectorState.drone);
    final f0 = active ? _StatusBox._f0(r) : 0.0;
    final trend = m.trendAvg;
    String dur;
    String durLabel;
    if (m.current != null) {
      durLabel = t.readDetectionTime;
      dur = fmtDuration(DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(m.current!.startMs)));
    } else {
      durLabel = t.readListeningTime;
      dur = m.listenStarted != null ? fmtDuration(DateTime.now().difference(m.listenStarted!)) : '–';
    }
    final items = <(String, String)>[
      (t.readBladePass, active ? t.ltr('${f0.round()} Hz') : '–'),
      (t.readRotorSpeed, active ? t.rpmValue(v: t.thousands(f0 * 30)) : '–'),
      (t.readHarmonic, active ? t.ltr('${(r.fr?.strength ?? 0).round()} dB') : '–'),
      (t.readTrend, active && r.state == DetectorState.drone ? (trend > 0.09 ? t.trendApproaching : trend < -0.09 ? t.trendAway : t.trendSteady) : '–'),
      (t.readAmbient, r != null ? t.ltr('${r.levelDb.round()} dBFS') : '–'),
      (durLabel, dur),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 520 ? 3 : 2;
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            for (final (label, value) in items)
              SizedBox(
                width: w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(label),
                    const SizedBox(height: 2),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFeatures: tabular)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReasonChips extends StatelessWidget {
  const _ReasonChips({required this.reasons});
  final Reasons reasons;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    final chips = <(String, bool)>[]; // (metin, drone yönünde mi)
    if (reasons.multiRotor != null) {
      chips.add(reasons.multiRotor! ? (t.cueMultiRotor, true) : (t.cueSingleRotor, false));
    }
    if (reasons.rpmJitter != null) {
      chips.add(reasons.rpmJitter! ? (t.cueSpeedVaries, true) : (t.cueSpeedSteady, false));
    }
    if (reasons.mainsLock != null) {
      chips.add(reasons.mainsLock! ? (t.cueMainsLocked, false) : (t.cueNotMains, true));
    }
    chips.add(reasons.levelSteady ? (t.cueLevelSteady, false) : (t.cueLevelVaries, true));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(t.cuesTitle),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (text, droneLike) in chips)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (droneLike ? dk.alert : dk.ok).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: (droneLike ? dk.alert : dk.ok).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(droneLike ? Icons.flight_rounded : Icons.mode_fan_off_rounded, size: 15, color: droneLike ? dk.alert : dk.ok),
                    const SizedBox(width: 5),
                    Text(text, style: TextStyle(fontSize: 12.5, color: dk.ink)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(t.cuesLegend,
            style: TextStyle(fontSize: 12, color: dk.muted)),
      ],
    );
  }
}
