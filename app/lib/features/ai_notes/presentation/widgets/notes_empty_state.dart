import 'package:flutter/material.dart';

/// FR-11: empty notes pane.
class NotesEmptyState extends StatelessWidget {
  const NotesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text('No notes yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Select text in your document, then pick an action such as Explain, Quiz or '
              'Key terms, or ask your own question about it. You can also drag a selection here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
