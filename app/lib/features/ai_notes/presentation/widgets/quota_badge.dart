import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/ai_notes_bloc.dart';

/// Remaining daily AI actions, once the backend has reported them (NFR-5).
class QuotaBadge extends StatelessWidget {
  const QuotaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return BlocSelector<AiNotesBloc, AiNotesState, int?>(
      selector: (state) => state.quota?.remaining,
      builder: (context, remaining) {
        if (remaining == null) return const SizedBox.shrink();
        final low = remaining <= 10;
        return Semantics(
          label: '$remaining AI actions left today',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: low ? scheme.errorContainer : scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$remaining left',
              style: theme.textTheme.labelSmall?.copyWith(
                color: low ? scheme.onErrorContainer : scheme.onSecondaryContainer,
              ),
            ),
          ),
        );
      },
    );
  }
}
