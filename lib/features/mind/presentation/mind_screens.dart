import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../me/presentation/me_screen.dart';
import '../data/mind_repository.dart';
import '../domain/mind_catalog.dart';

const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
String _date(DateTime d) => '${d.toLocal().day} ${_months[d.toLocal().month - 1]}';

VoidCallback _back(BuildContext context, String parent) =>
    () => context.canPop() ? context.pop() : context.go(parent);

/// Mind toolkit hub (design: Doji Me Phone › toolkit).
class MindToolkitScreen extends StatelessWidget {
  const MindToolkitScreen({super.key});

  @override
  Widget build(BuildContext context) => MeScaffold(
    title: 'mind toolkit',
    onBack: _back(context, Routes.me),
    children: [
      Text("small tools for the part of trading that isn't the chart.", style: DojiType.callout),
      for (final (icon, title, sub, route) in [
        (
          Icons.insights_outlined,
          'weekly scorecard',
          'how you kept your rules this week',
          Routes.mindScorecard,
        ),
        (Icons.style_outlined, 'reflection prompts', 'a card a day, answers saved', Routes.mindPrompts),
        (
          Icons.star_outline,
          'affirmation vault',
          'yours, plus one from doji each day',
          Routes.mindAffirmations,
        ),
        (
          Icons.menu_book_outlined,
          'reading list',
          'short reads and trading psychology books',
          Routes.mindReading,
        ),
      ])
        _ToolRow(icon: icon, title: title, sub: sub, onTap: () => context.go(route)),
    ],
  );
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.icon, required this.title, required this.sub, required this.onTap});

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: DojiPressable(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(DojiRadius.card),
      child: _Box(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: DojiColors.elevated2, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: DojiColors.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: DojiType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(sub, style: DojiType.callout.copyWith(fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: DojiColors.textTertiary),
          ],
        ),
      ),
    ),
  );
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.border = DojiColors.separator});

  final Widget child;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: DojiColors.elevated1,
      borderRadius: BorderRadius.circular(DojiRadius.card),
      border: Border.all(color: border),
    ),
    child: child,
  );
}

/// Weekly scorecard: discipline lines from the journal, the account's rules and mood check-ins.
/// The design's mindset slider and hand-counted rule breaks are replaced by measured lines.
class ScorecardScreen extends ConsumerWidget {
  const ScorecardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(scorecardProvider);
    return MeScaffold(
      title: 'weekly scorecard',
      onBack: _back(context, Routes.mind),
      children: [
        Text(
          'week of ${_date(card.weekStart)}',
          style: DojiType.label.copyWith(color: DojiColors.textSecondary),
        ),
        for (final l in card.lines)
          Semantics(
            container: true,
            label: '${l.title}: ${l.line}',
            child: ExcludeSemantics(
              child: _Box(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            l.title,
                            style: DojiType.callout.copyWith(color: DojiColors.textPrimary),
                          ),
                        ),
                        Text(
                          l.empty ? '–' : '${l.kept}/${l.sample}',
                          style: DojiType.data.copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.line,
                      style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Text(
          'counts how you kept your own rules on the active account. results are not part of it.',
          style: DojiType.callout.copyWith(fontSize: 13),
        ),
      ],
    );
  }
}

/// Reflection prompts: one card at a time, starting from today's, answers saved.
class PromptsScreen extends ConsumerStatefulWidget {
  const PromptsScreen({super.key});

  @override
  ConsumerState<PromptsScreen> createState() => _PromptsScreenState();
}

class _PromptsScreenState extends ConsumerState<PromptsScreen> {
  late int _i = promptStartOfDay(clock.now());
  bool _answering = false;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  MindPrompt get _prompt => kMindPrompts[_i % kMindPrompts.length];

  void _save() {
    ref.read(mindControllerProvider.notifier).answer(_prompt.id, _text.text);
    _text.clear();
    setState(() => _answering = false);
  }

  @override
  Widget build(BuildContext context) {
    final answers = ref.watch(mindControllerProvider).answers;
    final byId = {for (final p in kMindPrompts) p.id: p.text};
    return MeScaffold(
      title: 'reflection prompts',
      onBack: _back(context, Routes.mind),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DojiColors.elevated2,
            borderRadius: BorderRadius.circular(DojiRadius.sheet),
            border: Border.all(color: DojiColors.separator),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'card ${_i % kMindPrompts.length + 1} of ${kMindPrompts.length}',
                style: DojiType.label.copyWith(color: DojiColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(_prompt.text, style: DojiType.headline.copyWith(fontSize: 22)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DojiButton(
                      label: 'next card',
                      variant: DojiButtonVariant.outline,
                      size: DojiButtonSize.regular,
                      onPressed: () => setState(() {
                        _i++;
                        _answering = false;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DojiButton(
                      label: 'answer',
                      variant: DojiButtonVariant.neutral,
                      size: DojiButtonSize.regular,
                      onPressed: () => setState(() => _answering = true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_answering) ...[
          DojiTextField(
            controller: _text,
            hint: 'a sentence is enough',
            semanticLabel: 'your answer',
            maxLines: 3,
            minLines: 3,
            autofocus: true,
          ),
          DojiButton(label: 'save answer', size: DojiButtonSize.regular, onPressed: _save),
        ],
        Text('SAVED ANSWERS', style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary)),
        if (answers.isEmpty)
          Text('nothing saved yet.', style: DojiType.callout)
        else
          for (final a in answers)
            _Box(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${byId[a.promptId] ?? 'a prompt'} · ${_date(a.at)}',
                    style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(a.text, style: DojiType.callout.copyWith(color: DojiColors.textPrimary)),
                ],
              ),
            ),
      ],
    );
  }
}

/// Affirmation vault: today's from doji (seeded by date), the trader's own, favourites.
class AffirmationsScreen extends ConsumerStatefulWidget {
  const AffirmationsScreen({super.key});

  @override
  ConsumerState<AffirmationsScreen> createState() => _AffirmationsScreenState();
}

class _AffirmationsScreenState extends ConsumerState<AffirmationsScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add() {
    ref.read(mindControllerProvider.notifier).addOwn(_text.text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(mindControllerProvider);
    final c = ref.read(mindControllerProvider.notifier);
    final today = affirmationOfDay(clock.now());
    final todayFav = s.favourites.contains(today.id);
    final all = [...s.own, ...kAffirmations];
    // Favourites first, each group in its own order.
    final list = [
      ...all.where((a) => s.favourites.contains(a.id)),
      ...all.where((a) => !s.favourites.contains(a.id)),
    ];
    return MeScaffold(
      title: 'affirmation vault',
      onBack: _back(context, Routes.mind),
      children: [
        _Box(
          border: DojiColors.dojiGreen.withValues(alpha: .45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('> today', style: DojiType.label.copyWith(color: DojiColors.dojiGreen)),
              const SizedBox(height: 12),
              Text(today.text, style: DojiType.headline.copyWith(fontWeight: FontWeight.w400)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'written by doji for today',
                      style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary),
                    ),
                  ),
                  DojiButton(
                    label: todayFav ? 'in your favourites' : 'add to favourites',
                    variant: DojiButtonVariant.ghost,
                    size: DojiButtonSize.regular,
                    expand: false,
                    onPressed: () => c.toggleFavourite(today.id),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: DojiTextField(
                controller: _text,
                hint: 'write your own',
                semanticLabel: 'write your own',
                large: false,
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            DojiIconButton(icon: Icons.add, semanticLabel: 'add affirmation', filled: true, onPressed: _add),
          ],
        ),
        Column(
          children: [
            for (final a in list)
              Container(
                constraints: const BoxConstraints(minHeight: 56),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: DojiColors.elevated2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(a.text, style: DojiType.callout.copyWith(color: DojiColors.textPrimary)),
                    ),
                    _Star(
                      on: s.favourites.contains(a.id),
                      text: a.text,
                      onTap: () => c.toggleFavourite(a.id),
                    ),
                    if (a.own)
                      DojiIconButton(
                        icon: Icons.delete_outline,
                        semanticLabel: 'delete ${a.text}',
                        outlined: false,
                        onPressed: () => c.deleteOwn(a.id),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.on, required this.text, required this.onTap});

  final bool on;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: on,
    child: DojiIconButton(
      icon: on ? Icons.star : Icons.star_outline,
      semanticLabel: on ? 'favourite, $text' : 'not a favourite, $text',
      outlined: false,
      foreground: on ? DojiColors.dojiGreen : DojiColors.textSecondary,
      onPressed: onTap,
    ),
  );
}

/// Reading list: short articles (marked read once opened) and books the coach draws from.
class ReadingScreen extends ConsumerWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final read = ref.watch(mindControllerProvider).read;
    final articles = kReading.where((r) => !r.isBook);
    final books = kReading.where((r) => r.isBook);
    return MeScaffold(
      title: 'reading list',
      onBack: _back(context, Routes.mind),
      children: [
        Text(
          'short reads, and books on trading psychology that the coach draws from.',
          style: DojiType.callout,
        ),
        Text('SHORT READS', style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary)),
        for (final a in articles)
          Semantics(
            button: true,
            child: DojiPressable(
              onPressed: () => context.go(Routes.mindArticle(a.id)),
              borderRadius: BorderRadius.circular(DojiRadius.card),
              child: _Box(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            style: DojiType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          Text(a.summary, style: DojiType.callout.copyWith(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            '${a.minutes} min${read.contains(a.id) ? ' · read' : ''}',
                            style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: DojiColors.textTertiary),
                  ],
                ),
              ),
            ),
          ),
        Text('BOOKS', style: DojiType.label.copyWith(fontSize: 11, color: DojiColors.textSecondary)),
        for (final b in books)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DojiColors.elevated2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.title, style: DojiType.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(b.author!, style: DojiType.callout.copyWith(fontSize: 14)),
                Text(b.summary, style: DojiType.callout.copyWith(fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}

/// One short read. Opening it marks it read.
class ReadingArticleScreen extends ConsumerStatefulWidget {
  const ReadingArticleScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ReadingArticleScreen> createState() => _ReadingArticleScreenState();
}

class _ReadingArticleScreenState extends ConsumerState<ReadingArticleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(mindControllerProvider.notifier).markRead(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = kReading.where((r) => r.id == widget.id && !r.isBook).firstOrNull;
    return MeScaffold(
      title: a?.title ?? 'not found',
      onBack: _back(context, Routes.mindReading),
      children: [
        if (a == null)
          Text('this read is not on this device.', style: DojiType.callout)
        else ...[
          Text('${a.minutes} min read', style: DojiType.label.copyWith(color: DojiColors.textSecondary)),
          for (final p in a.paragraphs) Text(p, style: DojiType.body.copyWith(fontSize: 16)),
        ],
      ],
    );
  }
}
