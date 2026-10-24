import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/platform/platform_info.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/widgets.dart';

enum AuthLeading { none, back, close }

/// The frame every auth, app-lock and settings screen in the handoff shares:
/// grain over #050607, a 44pt header with a terminal prompt (`> auth --code`)
/// and an optional back chevron or close, content at the top (or centred),
/// actions pinned to the bottom.
///
/// Scrolls instead of clipping at large text sizes and above the keyboard;
/// Esc triggers the header action on Windows.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.body,
    this.prompt,
    this.promptAccent = DojiColors.dojiGreen,
    this.promptAllAccent = false,
    this.leading = AuthLeading.none,
    this.onLeading,
    this.actions = const [],
    this.centerBody = false,
    this.bodyGap = 16,
  });

  final List<Widget> body;

  /// Header text after `> `. Null hides the prompt (the 44pt row stays).
  final String? prompt;
  final Color promptAccent;

  /// "> 100% configured" is green from end to end.
  final bool promptAllAccent;
  final AuthLeading leading;
  final VoidCallback? onLeading;
  final List<Widget> actions;

  /// Vertically centre [body] between header and actions (A1, A8a, A9, A10).
  final bool centerBody;
  final double bodyGap;

  @override
  Widget build(BuildContext context) {
    final margin = PlatformInfo.isAndroid ? DojiSpace.screenMarginAndroid : DojiSpace.screenMargin;
    final target = DojiTokens.of(context).minTarget;

    final promptText = prompt == null
        ? const SizedBox.shrink()
        : Text.rich(
            TextSpan(
              style: DojiType.hint.copyWith(fontSize: 13, color: promptAllAccent ? promptAccent : null),
              children: [
                TextSpan(
                  text: '> ',
                  style: TextStyle(color: promptAccent),
                ),
                TextSpan(text: prompt),
              ],
            ),
          );

    final header = ConstrainedBox(
      constraints: BoxConstraints(minHeight: target),
      child: Row(
        children: [
          if (leading == AuthLeading.back) ...[
            Transform.translate(
              offset: const Offset(-12, 0),
              child: DojiIconButton(
                icon: Icons.chevron_left_rounded,
                iconSize: 30,
                semanticLabel: 'Back',
                outlined: false,
                background: Colors.transparent,
                onPressed: onLeading,
              ),
            ),
          ],
          // Handoff: chevron at margin-left -12, then a 2px gap.
          Expanded(
            child: Transform.translate(
              offset: Offset(leading == AuthLeading.back ? -10 : 0, 0),
              child: Align(alignment: Alignment.centerLeft, child: promptText),
            ),
          ),
          if (leading == AuthLeading.close) ...[
            Transform.translate(
              offset: const Offset(10, 0),
              child: DojiIconButton(
                icon: Icons.close_rounded,
                iconSize: 24,
                semanticLabel: 'Close',
                outlined: false,
                background: Colors.transparent,
                foreground: DojiColors.textSecondary,
                onPressed: onLeading,
              ),
            ),
          ],
        ],
      ),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: bodyGap),
        if (centerBody)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: body,
            ),
          )
        else ...[
          ...body,
          const Spacer(),
        ],
        if (actions.isNotEmpty) const SizedBox(height: 24),
        for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: 12), actions[i]],
      ],
    );

    Widget content = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(margin, 12, margin, 24),
          sliver: SliverFillRemaining(hasScrollBody: false, child: column),
        ),
      ],
    );
    if (onLeading != null) {
      content = CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onLeading!},
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: DojiColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.05)),
          SafeArea(
            child: Center(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: content),
            ),
          ),
        ],
      ),
    );
  }
}

/// Headline + secondary line, the handoff's `h1` + `p` pair.
class AuthHeadline extends StatelessWidget {
  const AuthHeadline(this.title, {super.key, this.sub, this.titleSpan});

  final String title;
  final Widget? sub;

  /// Rich title ("type `delete` to confirm.").
  final InlineSpan? titleSpan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        label: title,
        child: ExcludeSemantics(
          child: titleSpan == null
              ? Text(title, style: DojiType.largeTitle)
              : Text.rich(TextSpan(style: DojiType.largeTitle, children: [titleSpan!])),
        ),
      ),
      if (sub != null) ...[
        const SizedBox(height: 10),
        DefaultTextStyle.merge(
          style: DojiType.body.copyWith(color: DojiColors.textSecondary),
          child: sub!,
        ),
      ],
    ],
  );
}

/// The handoff's mono uppercase field label (`EMAIL`).
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: Text(text.toUpperCase(), style: DojiType.label));
}
