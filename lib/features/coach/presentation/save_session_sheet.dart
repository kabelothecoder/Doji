import 'package:flutter/material.dart';

import '../../../core/platform/platform_info.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';

enum LeaveChoice { save, discard }

/// Asked when a session with something you said closes unsaved (handoff 1c:
/// "asks to save if the transcript is unsaved"). Null = stay in the session.
/// Same glass sheet as sign out (A11).
Future<LeaveChoice?> showSaveSessionSheet(BuildContext context) => showModalBottomSheet<LeaveChoice>(
  context: context,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x8C000000),
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: DojiMotion.reduced(context)
      ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
      : null,
  builder: (context) => const _SaveSessionSheet(),
);

class _SaveSessionSheet extends StatelessWidget {
  const _SaveSessionSheet();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: 'Save session',
          explicitChildNodes: true,
          child: GlassSurface(
            radius: 40,
            tint: DojiColors.elevated2,
            fillOpacity: 0.78,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: DojiColors.separator,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'save this session?',
                    style: DojiType.headline.copyWith(fontSize: 22, letterSpacing: -0.44),
                  ),
                  const SizedBox(height: 12),
                  Text('the transcript is kept on this ${PlatformInfo.deviceNoun}.', style: DojiType.callout),
                  const SizedBox(height: 20),
                  DojiButton(
                    label: 'save',
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(LeaveChoice.save),
                  ),
                  const SizedBox(height: 12),
                  DojiButton(
                    label: "don't save",
                    variant: DojiButtonVariant.text,
                    size: DojiButtonSize.small,
                    onPressed: () => Navigator.of(context).pop(LeaveChoice.discard),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
