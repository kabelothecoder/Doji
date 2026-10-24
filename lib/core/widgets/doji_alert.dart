import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'doji_pressable.dart';
import 'glass_surface.dart';

/// Design system: `DojiAlert` (auth A12c, "showCupertinoDialog-style").
///
/// Centered glass card, title + message, stacked full-width actions with
/// hairlines. The destructive action is tilt-orange and sits on top, but
/// cancel takes focus first (keyboard and screen readers) so the default is
/// always the safe choice. Esc and a barrier tap also cancel.
///
/// Resolves to true only when [destructiveLabel] is chosen.
Future<bool> showDojiAlert(
  BuildContext context, {
  required String title,
  required String message,
  required String destructiveLabel,
  String cancelLabel = 'cancel',
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: const Color(0x99000000),
    transitionDuration: DojiMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 180),
    pageBuilder: (context, _, _) => DojiAlert(
      title: title,
      message: message,
      destructiveLabel: destructiveLabel,
      cancelLabel: cancelLabel,
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: DojiMotion.reduced(context) ? 1 : 1.04, end: 1).animate(animation),
        child: child,
      ),
    ),
  );
  return result ?? false;
}

class DojiAlert extends StatelessWidget {
  const DojiAlert({
    super.key,
    required this.title,
    required this.message,
    required this.destructiveLabel,
    this.cancelLabel = 'cancel',
  });

  final String title;
  final String message;
  final String destructiveLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    Widget action(String label, {required bool destructive, required double order}) => Semantics(
      sortKey: OrdinalSortKey(order),
      child: FocusTraversalOrder(
        order: NumericFocusOrder(order),
        child: DojiPressable(
          autofocus: !destructive,
          onPressed: () => Navigator.of(context).pop(destructive),
          semanticLabel: label,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DojiColors.separator)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: DojiType.button.copyWith(
                color: destructive ? DojiColors.tiltOrange : DojiColors.textPrimary,
                fontWeight: destructive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: title,
                child: FocusTraversalGroup(
                  policy: OrderedTraversalPolicy(),
                  child: GlassSurface(
                    radius: DojiRadius.sheet,
                    tint: DojiColors.elevated2,
                    fillOpacity: 0.82,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                            child: Column(
                              children: [
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: DojiType.headline.copyWith(fontSize: 19, letterSpacing: 0),
                                ),
                                const SizedBox(height: 8),
                                Text(message, textAlign: TextAlign.center, style: DojiType.callout),
                              ],
                            ),
                          ),
                          action(destructiveLabel, destructive: true, order: 2),
                          action(cancelLabel, destructive: false, order: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
