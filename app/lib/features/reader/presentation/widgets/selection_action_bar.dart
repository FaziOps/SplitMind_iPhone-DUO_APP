import 'package:flutter/material.dart';

import '../../../workspace/domain/entities/highlight.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../../workspace/presentation/widgets/synthesis_action_icon.dart';

/// Shown under the page while text is selected. The excerpt chip is the drag
/// source for cross-pane drag and drop (FR-3); the buttons are the non-drag
/// path to the same actions (FR-3a, NFR-6).
class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({super.key, required this.highlight, required this.onAction, required this.onClear});

  final Highlight highlight;

  /// null means "Send to AI" without running an action yet.
  final ValueChanged<SynthesisAction?> onAction;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _DraggableExcerpt(highlight: highlight)),
                  IconButton(tooltip: 'Clear selection', icon: const Icon(Icons.close), onPressed: onClear),
                ],
              ),
              const SizedBox(height: 8),
              // One scrolling row, so more actions never push the page off screen.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: Icon(SynthesisAction.ask.icon, size: 18),
                      label: const Text('Ask or send to AI'),
                      tooltip: 'Open the passage in AI notes to ask a question',
                      onPressed: () => onAction(null),
                    ),
                    for (final action in SynthesisAction.quickActions)
                      ActionChip(
                        avatar: Icon(action.icon, size: 18),
                        label: Text(action.label),
                        onPressed: () => onAction(action),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraggableExcerpt extends StatelessWidget {
  const _DraggableExcerpt({required this.highlight});

  final Highlight highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final excerpt = Row(
      children: [
        Icon(Icons.drag_indicator, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '“${highlight.text}”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );

    return Semantics(
      label: 'Selected text: ${highlight.text}',
      hint: 'Drag to AI notes, or use the actions below',
      excludeSemantics: true,
      child: Draggable<Highlight>(
        data: highlight,
        // The feedback floats above the tree and loses inherited theme data,
        // so it needs its own Material (PRD Section 3 note).
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: scheme.primaryContainer,
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(12),
            child: Text(
              highlight.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: excerpt),
        child: excerpt,
      ),
    );
  }
}
