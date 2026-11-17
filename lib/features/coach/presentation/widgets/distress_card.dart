import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../panic/presentation/panic_screen.dart' show kSadagNumber;

/// Doji Coach Phone › distress: the SADAG line first, then "take a minute
/// with me" (the panic flow), then "keep talking". Replaces the push-to-talk
/// row so nothing on screen asks for anything fast.
class DistressCard extends StatefulWidget {
  const DistressCard({super.key, required this.onPanic, required this.onKeepTalking});

  final VoidCallback onPanic;
  final VoidCallback onKeepTalking;

  @override
  State<DistressCard> createState() => _DistressCardState();
}

class _DistressCardState extends State<DistressCard> {
  bool _callFailed = false;

  Future<void> _call() async {
    var ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'tel', path: kSadagNumber.replaceAll(' ', '')));
    } catch (_) {}
    if (!ok && mounted) setState(() => _callFailed = true);
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.card),
      border: Border.all(color: DojiColors.separator),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text('want to slow down together first?', style: DojiType.headline.copyWith(fontSize: 17)),
        ),
        const SizedBox(height: 10),
        DojiPressable(
          onPressed: _call,
          semanticLabel: 'talk to someone now, SADAG, $kSadagNumber, free, 24/7',
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DojiColors.separator),
            ),
            child: Row(
              children: [
                const Icon(Icons.call_outlined, size: 20, color: DojiColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('talk to someone now · SADAG', style: DojiType.body.copyWith(fontSize: 15)),
                      Text('$kSadagNumber · free, 24/7', style: DojiType.hint.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_callFailed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "this device can't call. dial $kSadagNumber from a phone.",
              style: DojiType.callout.copyWith(fontSize: 13),
            ),
          ),
        const SizedBox(height: 10),
        DojiButton(label: 'take a minute with me', onPressed: widget.onPanic),
        DojiButton(
          label: 'keep talking',
          variant: DojiButtonVariant.text,
          size: DojiButtonSize.small,
          onPressed: widget.onKeepTalking,
        ),
      ],
    ),
  );
}
