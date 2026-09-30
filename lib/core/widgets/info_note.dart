import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Design system: `InfoNote(tone: tilt)` — the calm orange note from the risk
/// step. Tinted fill, full hairline, icon + copy, so it reads without colour.
/// A note, never a block.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'note: $text',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: DojiColors.orangeTint,
            borderRadius: BorderRadius.circular(DojiRadius.card),
            border: Border.all(color: DojiColors.orangeHairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: DojiColors.tiltOrange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: DojiType.callout.copyWith(color: DojiColors.textPrimary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
