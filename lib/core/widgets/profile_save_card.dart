import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'config_panel.dart';
import 'glass_surface.dart';

enum ProfileSaveStatus { readyToSave, saving, saved }

/// Design system: `ProfileSaveCard` (auth component spec, A2 · A6).
/// "ClipRRect(24) › BackdropFilter(blur 28) › Container(#0F1113 @ 60%, 1px
/// white 8%) › Column of ConfigLine". Reads as a list for screen readers.
class ProfileSaveCard extends StatelessWidget {
  const ProfileSaveCard({
    super.key,
    required this.lines,
    required this.totalLines,
    this.status = ProfileSaveStatus.readyToSave,
    this.footer = 'stored on this device only',
  });

  /// The mini profile: a handful of representative lines.
  final List<ConfigLineData> lines;

  /// All lines in the full profile.doji.
  final int totalLines;
  final ProfileSaveStatus status;
  final String footer;

  String get _pill => switch (status) {
    ProfileSaveStatus.readyToSave => 'READY TO SAVE',
    ProfileSaveStatus.saving => 'SAVING…',
    ProfileSaveStatus.saved => 'SYNCED',
  };

  Color _valueColor(ConfigValueTone t) => switch (t) {
    ConfigValueTone.symbol => DojiColors.dojiGreen,
    ConfigValueTone.muted => DojiColors.textSecondary,
    ConfigValueTone.literal => DojiColors.textPrimary,
  };

  @override
  Widget build(BuildContext context) {
    final mono = DojiType.configWide;
    return Semantics(
      container: true,
      label: 'profile dot doji, $totalLines lines, ${_pill.toLowerCase()}',
      child: ExcludeSemantics(
        child: GlassSurface(
          radius: DojiRadius.sheet,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: DojiColors.dojiGreen),
                  const SizedBox(width: 8),
                  Text('profile.doji', style: mono.copyWith(fontSize: 13)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: DojiColors.greenTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _pill,
                      style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.dojiGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: Text(
                          l.number.toString().padLeft(2, '0'),
                          textAlign: TextAlign.right,
                          style: mono.copyWith(color: DojiColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: mono.copyWith(height: 1.5),
                            children: [
                              TextSpan(
                                text: '${l.keyName}: ',
                                style: const TextStyle(color: DojiColors.textSecondary),
                              ),
                              TextSpan(
                                text: l.value,
                                style: TextStyle(color: _valueColor(l.tone)),
                              ),
                              TextSpan(
                                text: l.comment,
                                style: const TextStyle(color: DojiColors.textSecondary),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: DojiColors.separator)),
                ),
                child: Text('$totalLines lines · $footer', style: DojiType.hint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
