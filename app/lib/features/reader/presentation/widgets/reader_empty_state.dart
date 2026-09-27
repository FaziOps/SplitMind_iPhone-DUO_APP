import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/reader_bloc.dart';

/// FR-11: no document loaded (or the last one failed to open).
class ReaderEmptyState extends StatelessWidget {
  const ReaderEmptyState({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = errorMessage != null;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.menu_book_outlined,
                size: 56,
                color: isError ? scheme.error : scheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                isError ? "Couldn't open the document" : 'Open a document to start',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? 'Read a PDF here, highlight a passage, and SplitMind builds notes alongside it.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.read<ReaderBloc>().add(const ReaderImportRequested()),
                icon: const Icon(Icons.upload_file),
                label: const Text('Import a PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.read<ReaderBloc>().add(const ReaderSampleRequested()),
                child: const Text('Try the sample document'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
