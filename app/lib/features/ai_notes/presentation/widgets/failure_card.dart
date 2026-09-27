import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/ai_exceptions.dart';
import '../bloc/ai_notes_bloc.dart';

/// FR-11: a distinct message and icon per failure type.
class FailureCard extends StatelessWidget {
  const FailureCard({super.key, required this.failure});

  final AiRequestException failure;

  (IconData, String) get _presentation => switch (failure) {
    NetworkException() => (Icons.wifi_off, 'No connection'),
    RequestTimeoutException() => (Icons.timer_off_outlined, 'Request timed out'),
    QuotaExceededException() => (Icons.hourglass_bottom, 'Daily limit reached'),
    RateLimitedException() => (Icons.speed, 'Slow down a little'),
    SafetyBlockedException() => (Icons.shield_outlined, "Can't process this passage"),
    ContentRestrictedException() => (Icons.lock_outline, 'Text extraction not allowed'),
    InvalidRequestException() => (Icons.text_fields, "Can't send this selection"),
    UnauthorizedException() => (Icons.key_off_outlined, 'Session expired'),
    ServerException() => (Icons.cloud_off_outlined, 'AI service unavailable'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, title) = _presentation;
    final bloc = context.read<AiNotesBloc>();
    return Semantics(
      liveRegion: true,
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall?.copyWith(color: scheme.onErrorContainer)),
                        const SizedBox(height: 4),
                        Text(
                          failure.message,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => bloc.add(const FailureDismissed()),
                      style: TextButton.styleFrom(foregroundColor: scheme.onErrorContainer),
                      child: const Text('Dismiss'),
                    ),
                    if (failure.isRetryable)
                      TextButton(
                        onPressed: () => bloc.add(const RetryRequested()),
                        style: TextButton.styleFrom(foregroundColor: scheme.onErrorContainer),
                        child: const Text('Try again'),
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
