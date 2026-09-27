import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../../workspace/presentation/bloc/active_workspace_bloc.dart';
import '../../../workspace/presentation/widgets/synthesis_action_icon.dart';
import '../../domain/entities/ai_note.dart';
import '../bloc/ai_notes_bloc.dart';
import 'flashcard_deck.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note});

  final AiNote note;

  String? get _citation {
    final parts = [if (note.sourcePage != null) 'p. ${note.sourcePage}', ?note.sourceDocTitle];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final citation = _citation;
    final question = note.question;
    final cards = note.action == SynthesisAction.flashcard ? parseFlashcards(note.markdown) : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(note.action.icon, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(note.action.label, style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
                const SizedBox(width: 4),
                if (citation != null)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CitationButton(note: note, citation: citation),
                    ),
                  )
                else
                  const Spacer(),
                PopupMenuButton<_NoteMenu>(
                  tooltip: 'Note options',
                  onSelected: (item) => _onMenu(context, item),
                  itemBuilder: (context) => [
                    if (note.sourcePage != null)
                      PopupMenuItem(value: _NoteMenu.goToSource, child: Text('Go to page ${note.sourcePage}')),
                    const PopupMenuItem(value: _NoteMenu.copy, child: Text('Copy as Markdown')),
                    const PopupMenuItem(value: _NoteMenu.delete, child: Text('Delete note')),
                  ],
                ),
              ],
            ),
            if (question != null)
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 4),
                child: Text('Q: $question', style: theme.textTheme.titleSmall),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: cards != null ? FlashcardDeck(cards: cards) : MarkdownBody(data: note.markdown, selectable: true),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'Source: “${note.sourceText}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, _NoteMenu item) async {
    switch (item) {
      case _NoteMenu.goToSource:
        _goToSource(context, note);
      case _NoteMenu.copy:
        await Clipboard.setData(ClipboardData(text: note.markdown));
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Note copied')));
        }
      case _NoteMenu.delete:
        final bloc = context.read<AiNotesBloc>();
        bloc.add(NoteDeleted(note.id));
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Note deleted'),
              action: SnackBarAction(label: 'Undo', onPressed: () => bloc.add(NoteRestored(note))),
            ),
          );
    }
  }
}

/// FR-8: every note links back to the page it came from.
void _goToSource(BuildContext context, AiNote note) {
  final page = note.sourcePage;
  if (page == null) return;
  context.read<ActiveWorkspaceBloc>().add(SourcePageRequested(docId: note.sourceDocId, page: page));
}

class _CitationButton extends StatelessWidget {
  const _CitationButton({required this.note, required this.citation});

  final AiNote note;
  final String citation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = Text(
      '·  $citation',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        color: note.sourcePage == null ? scheme.onSurfaceVariant : scheme.primary,
        decoration: note.sourcePage == null ? null : TextDecoration.underline,
        decorationColor: scheme.primary,
      ),
    );
    if (note.sourcePage == null) return label;
    return Semantics(
      container: true,
      button: true,
      label: 'Go to source, page ${note.sourcePage}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _goToSource(context, note),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8), child: label),
      ),
    );
  }
}

enum _NoteMenu { goToSource, copy, delete }
