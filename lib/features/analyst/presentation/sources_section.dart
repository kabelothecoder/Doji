import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/widgets.dart';
import 'analyst_controller.dart';

/// Opens the system picker for one PDF; null when cancelled. A provider so
/// tests can answer without a platform channel.
final pickPdfProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    return files.firstOrNull?.name;
  },
);

/// "my sources" in the account editor: the trader's own notes and PDFs about
/// their strategy. Saved at once, apart from "save", like the broker link.
class SourcesSection extends ConsumerStatefulWidget {
  const SourcesSection({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<SourcesSection> createState() => _SourcesSectionState();
}

class _SourcesSectionState extends ConsumerState<SourcesSection> {
  final _title = TextEditingController();
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    await ref.read(sourcesProvider.notifier).addNote(widget.accountId, _title.text, _text.text);
    _title.clear();
    _text.clear();
  }

  Future<void> _addPdf() async {
    final name = await ref.read(pickPdfProvider)();
    if (name == null || !mounted) return;
    await ref.read(sourcesProvider.notifier).addFile(widget.accountId, name);
  }

  @override
  Widget build(BuildContext context) {
    final mine = [
      for (final s in ref.watch(sourcesProvider))
        if (s.accountId == widget.accountId) s,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'notes and pdfs about your strategy. the analyst and the co-pilot read your notes. '
          'saved at once, on this device.',
          style: DojiType.callout,
        ),
        const SizedBox(height: 12),
        for (final s in mine)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  s.isFile ? Icons.picture_as_pdf_outlined : Icons.notes_rounded,
                  size: 18,
                  color: DojiColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: DojiType.body.copyWith(fontSize: 15)),
                      Text(
                        s.isFile ? 'pdf · read once sync is on' : 'note · ${s.text.length} characters',
                        style: DojiType.hint,
                      ),
                    ],
                  ),
                ),
                DojiIconButton(
                  icon: Icons.delete_outline_rounded,
                  semanticLabel: 'remove ${s.title}',
                  outlined: false,
                  background: Colors.transparent,
                  onPressed: () => unawaited(ref.read(sourcesProvider.notifier).remove(s.id)),
                ),
              ],
            ),
          ),
        DojiTextField(controller: _title, large: false, hint: 'note title', semanticLabel: 'note title'),
        const SizedBox(height: 8),
        DojiTextField(
          controller: _text,
          large: false,
          hint: 'your note',
          semanticLabel: 'note text',
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DojiButton(
              label: 'add note',
              variant: DojiButtonVariant.secondary,
              size: DojiButtonSize.small,
              expand: false,
              onPressed: _text.text.trim().isEmpty ? null : () => unawaited(_addNote()),
            ),
            DojiButton(
              label: 'add a pdf',
              variant: DojiButtonVariant.outline,
              size: DojiButtonSize.small,
              expand: false,
              onPressed: () => unawaited(_addPdf()),
            ),
          ],
        ),
      ],
    );
  }
}
