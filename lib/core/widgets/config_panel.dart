import 'package:flutter/material.dart';

import '../platform/platform_info.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'doji_animated_size.dart';
import 'doji_pressable.dart';
import 'glass_surface.dart';

/// How a value is coloured in profile.doji: quoted strings and numbers in
/// white, enums and lists in doji-green, nulls/skips in grey.
enum ConfigValueTone { literal, symbol, muted }

@immutable
class ConfigLineData {
  const ConfigLineData({
    required this.number,
    required this.keyName,
    required this.value,
    required this.tone,
    required this.targetId,
    this.comment = '',
    this.highlighted = false,
  });

  final int number;
  final String keyName;
  final String value;
  final ConfigValueTone tone;

  /// Trailing `  # comment` in grey.
  final String comment;

  /// Onboarding step to open when the line is tapped.
  final String targetId;

  /// The most recently written line (green tint).
  final bool highlighted;

  ConfigLineData copyWith({int? number, bool? highlighted}) => ConfigLineData(
    number: number ?? this.number,
    keyName: keyName,
    value: value,
    tone: tone,
    targetId: targetId,
    comment: comment,
    highlighted: highlighted ?? this.highlighted,
  );

  @override
  bool operator ==(Object other) =>
      other is ConfigLineData &&
      other.number == number &&
      other.keyName == keyName &&
      other.value == value &&
      other.tone == tone &&
      other.comment == comment &&
      other.targetId == targetId &&
      other.highlighted == highlighted;

  @override
  int get hashCode => Object.hash(number, keyName, value, tone, comment, targetId, highlighted);
}

enum ConfigPanelLayout {
  /// Phones and narrow windows: collapsible glass card above the conversation.
  compact,

  /// Wide windows: full-height editor pane on the right (520px).
  pane,
}

/// Design system: `ProfileDojiPanel` in the handoff's Flutter map
/// (`ConfigPanel` in the brief) — the live `profile.doji` file.
///
/// Every line is tappable and opens its step for editing. Rows are 44pt on
/// touch platforms (accessibility floor) and 32px on desktop, as in the
/// Windows handoff.
class ConfigPanel extends StatefulWidget {
  const ConfigPanel({
    super.key,
    required this.lines,
    required this.totalLines,
    required this.onEditLine,
    this.layout = ConfigPanelLayout.compact,
    this.collapsed = false,
    this.onToggleCollapsed,
    this.visibleLines = 3,
    this.firstLineFocusNode,
  });

  final List<ConfigLineData> lines;
  final int totalLines;
  final ValueChanged<ConfigLineData> onEditLine;
  final ConfigPanelLayout layout;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  /// Rows visible in the compact card when expanded (collapsed shows one).
  final int visibleLines;

  /// Focus target for the desktop "ctrl+E" shortcut.
  final FocusNode? firstLineFocusNode;

  @override
  State<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<ConfigPanel> {
  final _scroll = ScrollController();

  /// Fixed extent keeps scrolling cheap, but it must still grow with text size
  /// (up to 200%) so lines never clip.
  double get _rowHeight {
    final base = PlatformInfo.isDesktop ? 32.0 : DojiTokens.of(context).minTarget;
    final scaledLine = MediaQuery.textScalerOf(context).scale(14) * 1.4 + 8;
    return scaledLine > base ? scaledLine : base;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd(animate: false));
  }

  @override
  void didUpdateWidget(ConfigPanel old) {
    super.didUpdateWidget(old);
    final newest = widget.lines.where((l) => l.highlighted).firstOrNull;
    final oldNewest = old.lines.where((l) => l.highlighted).firstOrNull;
    if (old.lines.length != widget.lines.length || newest != oldNewest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlighted());
    }
  }

  void _scrollToEnd({bool animate = true}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animate && !DojiMotion.reduced(context)) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _scrollToHighlighted() {
    if (!_scroll.hasClients || !mounted) return;
    final i = widget.lines.indexWhere((l) => l.highlighted);
    if (i < 0) return _scrollToEnd();
    final rows = widget.collapsed ? 1 : widget.visibleLines;
    final target = ((i - rows + 1) * _rowHeight).clamp(0.0, _scroll.position.maxScrollExtent);
    if (DojiMotion.reduced(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _count => widget.lines.isEmpty ? 'empty' : '${widget.lines.length} / ${widget.totalLines} lines';

  @override
  Widget build(BuildContext context) =>
      widget.layout == ConfigPanelLayout.pane ? _buildPane(context) : _buildCompact(context);

  Widget _buildCompact(BuildContext context) {
    final rows = widget.collapsed ? 1 : widget.visibleLines;
    final shown = rows.clamp(1, widget.lines.isEmpty ? 1 : widget.lines.length);
    final minTarget = DojiTokens.of(context).minTarget;
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DojiPressable(
            onPressed: widget.onToggleCollapsed,
            semanticLabel:
                'profile dot doji, ${widget.lines.length} of ${widget.totalLines} lines, '
                '${widget.collapsed ? 'collapsed' : 'expanded'}',
            semanticHint: widget.collapsed ? 'expand' : 'collapse',
            showPressedOverlay: false,
            pressedScale: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minTarget),
              child: Row(
                children: [
                  Icon(
                    widget.collapsed ? Icons.chevron_right_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: DojiColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'profile.doji',
                      style: DojiType.hint.copyWith(color: DojiColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      _count,
                      style: DojiType.hint,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ),
          DojiAnimatedSize(
            child: SizedBox(
              height: shown * _rowHeight,
              child: ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.zero,
                itemExtent: _rowHeight,
                itemCount: widget.lines.length,
                itemBuilder: (context, i) => _ConfigRow(
                  line: widget.lines[i],
                  height: _rowHeight,
                  style: DojiType.config,
                  onTap: () => widget.onEditLine(widget.lines[i]),
                  focusNode: i == 0 ? widget.firstLineFocusNode : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPane(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DojiColors.elevated1,
        border: Border(left: BorderSide(color: DojiColors.separator)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DojiColors.separator)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 18, color: DojiColors.dojiGreen),
                const SizedBox(width: 8),
                Semantics(
                  header: true,
                  child: Text('profile.doji', style: DojiType.configWide.copyWith(fontSize: 13)),
                ),
                const Spacer(),
                Text(
                  _count,
                  style: DojiType.configWide.copyWith(fontSize: 13, color: DojiColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemExtent: _rowHeight,
              itemCount: widget.lines.length,
              itemBuilder: (context, i) => _ConfigRow(
                line: widget.lines[i],
                height: _rowHeight,
                style: DojiType.configWide,
                numberWidth: 20,
                gap: 14,
                showEditIcon: false,
                onTap: () => widget.onEditLine(widget.lines[i]),
                focusNode: i == 0 ? widget.firstLineFocusNode : null,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DojiColors.separator)),
            ),
            child: Text('click a line to edit · ctrl+E', style: DojiType.hint),
          ),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({
    required this.line,
    required this.height,
    required this.style,
    required this.onTap,
    this.numberWidth = 16,
    this.gap = 10,
    this.showEditIcon = true,
    this.focusNode,
  });

  final ConfigLineData line;
  final double height;
  final TextStyle style;
  final VoidCallback onTap;
  final double numberWidth;
  final double gap;
  final bool showEditIcon;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final valueColor = switch (line.tone) {
      ConfigValueTone.literal => DojiColors.textPrimary,
      ConfigValueTone.symbol => DojiColors.dojiGreen,
      ConfigValueTone.muted => DojiColors.textSecondary,
    };
    final radius = BorderRadius.circular(6);
    return DojiPressable(
      onPressed: onTap,
      borderRadius: radius,
      focusNode: focusNode,
      semanticLabel: 'edit ${line.keyName}: ${line.value}',
      pressedScale: 1,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: line.highlighted ? DojiColors.greenTint : Colors.transparent,
          borderRadius: radius,
        ),
        child: Row(
          children: [
            SizedBox(
              width: numberWidth,
              child: Text(
                '${line.number}',
                textAlign: TextAlign.right,
                style: style.copyWith(color: DojiColors.textSecondary),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    TextSpan(
                      text: '${line.keyName}: ',
                      style: const TextStyle(color: DojiColors.textSecondary),
                    ),
                    TextSpan(
                      text: line.value,
                      style: TextStyle(color: valueColor),
                    ),
                    if (line.comment.isNotEmpty)
                      TextSpan(
                        text: line.comment,
                        style: const TextStyle(color: DojiColors.textSecondary),
                      ),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showEditIcon)
              Opacity(
                opacity: line.highlighted ? 1 : 0.5,
                child: const Icon(Icons.edit_outlined, size: 15, color: DojiColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
