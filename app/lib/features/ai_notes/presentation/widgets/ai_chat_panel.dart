import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../workspace/domain/entities/highlight.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../../workspace/presentation/bloc/active_workspace_bloc.dart';
import '../../../workspace/presentation/widgets/synthesis_action_icon.dart';
import '../../domain/entities/ai_note.dart';
import '../bloc/ai_notes_bloc.dart';
import 'context_card.dart';
import 'failure_card.dart';
import 'note_card.dart';
import 'notes_empty_state.dart';
import 'pending_card.dart';
import 'quota_badge.dart';

/// The right pane: AI chat and synthesis. It is also the drop target for text
/// dragged from the reader (FR-3).
class AiChatPanel extends StatelessWidget {
  const AiChatPanel({super.key, this.scrollController, this.onClose});

  /// Supplied by the floating overlay so dragging the list moves the sheet.
  final ScrollController? scrollController;

  /// Shown as a close button when the panel is an overlay.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<Highlight>(
      onAcceptWithDetails: (details) {
        context.read<ActiveWorkspaceBloc>().add(HighlightSentToAi(details.data));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovering ? scheme.primaryContainer.withValues(alpha: 0.35) : scheme.surface,
            border: isHovering ? Border.all(color: scheme.primary, width: 2) : null,
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              PinnedHeaderSliver(
                child: _Header(isHovering: isHovering, onClose: onClose),
              ),
              const SliverPadding(padding: EdgeInsets.fromLTRB(16, 8, 16, 32), sliver: _Body()),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isHovering, this.onClose});

  final bool isHovering;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: isHovering ? scheme.primaryContainer : scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClose != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: isHovering ? scheme.onPrimaryContainer : scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    liveRegion: isHovering,
                    child: Text(
                      isHovering ? 'Drop text here to analyze' : 'AI Notes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isHovering ? scheme.onPrimaryContainer : null,
                      ),
                    ),
                  ),
                ),
                const QuotaBadge(),
                if (onClose != null)
                  IconButton(tooltip: 'Close AI notes', icon: const Icon(Icons.close), onPressed: onClose)
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Show only notes of this kind; null shows all.
  SynthesisAction? _filter;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiNotesBloc, AiNotesState>(
      builder: (context, state) {
        if (state.status == AiNotesStatus.restoring) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(semanticsLabel: 'Restoring notes')),
          );
        }

        final context_ = state.context;
        final pending = state.pending;
        final failure = state.failure;
        final isEmpty = context_ == null && pending == null && failure == null && state.notes.isEmpty;
        if (isEmpty) {
          return const SliverFillRemaining(hasScrollBody: false, child: NotesEmptyState());
        }

        // A filter whose last note was deleted falls back to "All".
        final present = {for (final n in state.notes) n.action};
        final filter = present.contains(_filter) ? _filter : null;
        final visible = filter == null
            ? state.notes
            : [
                for (final n in state.notes)
                  if (n.action == filter) n,
              ];

        const gap = SizedBox(height: 12);
        return SliverList.list(
          children: [
            if (context_ != null) ...[ContextCard(highlight: context_, isBusy: state.isGenerating), gap],
            if (pending != null) ...[PendingCard(command: pending), gap],
            if (failure != null) ...[FailureCard(failure: failure), gap],
            if (present.length > 1) ...[
              _NotesFilter(notes: state.notes, selected: filter, onSelected: (a) => setState(() => _filter = a)),
              gap,
            ],
            for (final note in visible) ...[NoteCard(key: ValueKey(note.id), note: note), gap],
          ],
        );
      },
    );
  }
}

/// Narrows a long notes list to one kind of note, with a count for each.
class _NotesFilter extends StatelessWidget {
  const _NotesFilter({required this.notes, required this.selected, required this.onSelected});

  final List<AiNote> notes;
  final SynthesisAction? selected;
  final ValueChanged<SynthesisAction?> onSelected;

  @override
  Widget build(BuildContext context) {
    final counts = <SynthesisAction, int>{};
    for (final note in notes) {
      counts[note.action] = (counts[note.action] ?? 0) + 1;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 8,
        children: [
          ChoiceChip(
            label: Text('All ${notes.length}'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final action in SynthesisAction.values)
            if (counts[action] case final count?)
              ChoiceChip(
                avatar: Icon(action.icon, size: 18),
                label: Text('${action.label} $count'),
                selected: selected == action,
                onSelected: (_) => onSelected(selected == action ? null : action),
              ),
        ],
      ),
    );
  }
}
