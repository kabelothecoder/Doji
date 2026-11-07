import 'package:flutter/material.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';

/// The chart's sheets, framed like the journal's review sheet (glass,
/// elevated-2, grabber, 560 max width). No design file: built from
/// `GlassSurface` (design/SOURCE.md › Missing).
Future<T?> showChartSheet<T>(BuildContext context, {required String label, required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x8C000000),
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: DojiMotion.reduced(context)
          ? const AnimationStyle(duration: Duration.zero, reverseDuration: Duration.zero)
          : null,
      builder: (context) => ChartSheetFrame(label: label, child: builder(context)),
    );

class ChartSheetFrame extends StatelessWidget {
  const ChartSheetFrame({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: label,
          child: GlassSurface(
            radius: DojiRadius.sheet,
            tint: DojiColors.elevated2,
            fillOpacity: 0.9,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3D42),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
