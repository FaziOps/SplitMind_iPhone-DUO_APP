import 'package:flutter/material.dart';

import '../../../workspace/domain/entities/synthesis_action.dart';

/// FR-11: AI request in progress.
class PendingCard extends StatelessWidget {
  const PendingCard({super.key, required this.command});

  final SynthesisCommand command;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: '${command.action.progressLabel}, please wait',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${command.action.progressLabel}…', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      command.question ?? command.highlight.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
