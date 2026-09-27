import 'package:flutter/material.dart';

import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../../workspace/presentation/widgets/synthesis_action_icon.dart';

/// A self-contained, offline demo of the reader/notes interaction. Nothing
/// here calls the backend.
class DualPaneDemo extends StatefulWidget {
  const DualPaneDemo({super.key});

  @override
  State<DualPaneDemo> createState() => _DualPaneDemoState();
}

class _DualPaneDemoState extends State<DualPaneDemo> {
  SynthesisAction? _action;

  static const _passage =
      'Spaced repetition schedules reviews at growing intervals, so each review happens just before you would forget.';

  static const _outputs = {
    SynthesisAction.explain: 'You remember more when you review right before forgetting, and wait longer each time.',
    SynthesisAction.summarize: '• Reviews are spaced out\n• Intervals grow over time\n• Timing beats repetition count',
    SynthesisAction.flashcard: 'Q: When should the next review happen?\nA: Just before you would forget.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final action = _action;

    Widget pane({required Widget child, Color? color}) => Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: child,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pane(
                child: Text(
                  _passage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    backgroundColor: action == null ? null : scheme.primaryContainer,
                    color: action == null ? null : scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              pane(
                color: scheme.surfaceContainer,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: action == null
                      ? Text(
                          'Notes appear here',
                          key: const ValueKey('empty'),
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        )
                      : Semantics(
                          liveRegion: true,
                          child: Column(
                            key: ValueKey(action),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(action.label, style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
                              const SizedBox(height: 4),
                              Text(_outputs[action]!, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final a in _outputs.keys)
              ChoiceChip(
                avatar: Icon(a.icon, size: 18),
                label: Text(a.label),
                selected: a == action,
                onSelected: (_) => setState(() => _action = a),
              ),
          ],
        ),
      ],
    );
  }
}
