import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/strings.dart';
import 'common.dart';

/// İzin istemeden önce kısa açıklama (Apple'ın önerdiği "ön izin" ekranı): mikrofon ve bildirim neden
/// gerekli. Yalnızca mikrofon izni henüz sorulmamışsa gösterilir. true: devam; aşağı kaydırıp kapatmak: vazgeç.
Future<bool> showPermissionPrimer(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => const PermissionPrimer(),
  );
  return ok ?? false;
}

class PermissionPrimer extends StatelessWidget {
  const PermissionPrimer({super.key});

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    final t = S.of(context);
    return Container(
      decoration: BoxDecoration(
        color: dk.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: dk.line)),
      ),
      // Ortam sorusuyla aynı düzen: buton hep görünür, içerik sığmazsa orantılı küçülür.
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
                    TwoToneTitle(t.permTitle, size: 24),
                    const SizedBox(height: 6),
                    Text(t.permIntro, style: body(14, dk.muted)),
                    const SizedBox(height: 14),
                    _Reason(icon: Icons.mic_rounded, title: t.permMicTitle, text: t.permMicText),
                    const SizedBox(height: 8),
                    _Reason(icon: Icons.notifications_active_rounded, title: t.notifications, text: t.permNotifText),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: GradientButton(t.continueButton, onPressed: () => Navigator.of(context).pop(true)),
          ),
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final dk = context.dk;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dk.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dk.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dk.brand.withValues(alpha: 0.16)),
            child: Icon(icon, size: 22, color: dk.brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: body(16, dk.ink, weight: FontWeight.w600).copyWith(height: 1.2)),
                const SizedBox(height: 4),
                Text(text, style: body(13, dk.muted).copyWith(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
