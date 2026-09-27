import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../workspace/domain/entities/highlight.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../../workspace/presentation/widgets/synthesis_action_icon.dart';
import '../bloc/ai_notes_bloc.dart';

/// The passage sent to the notes pane, with the actions to run on it and a
/// field for asking a question about it.
class ContextCard extends StatefulWidget {
  const ContextCard({super.key, required this.highlight, required this.isBusy});

  final Highlight highlight;
  final bool isBusy;

  /// One-tap starting points for readers who don't know what to ask.
  static const suggestedQuestions = [
    'Why does this matter?',
    'Give me a real-world example',
    'What is the main point?',
  ];

  @override
  State<ContextCard> createState() => _ContextCardState();
}

class _ContextCardState extends State<ContextCard> {
  final _question = TextEditingController();

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _run(SynthesisAction action) => context.read<AiNotesBloc>().add(GenerateRequested(action));

  void _ask([String? preset]) {
    final question = (preset ?? _question.text).trim();
    if (question.isEmpty || widget.isBusy) return;
    context.read<AiNotesBloc>().add(GenerateRequested(SynthesisAction.ask, question: question));
    _question.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final citation = widget.highlight.citation;
    final isBusy = widget.isBusy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    citation == null ? 'Selected passage' : 'Selected passage · $citation',
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss passage',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => context.read<AiNotesBloc>().add(const ContextDismissed()),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: scheme.primary, width: 3)),
                ),
                child: Text(
                  widget.highlight.text,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final action in SynthesisAction.quickActions)
                  FilledButton.tonalIcon(
                    onPressed: isBusy ? null : () => _run(action),
                    icon: Icon(action.icon, size: 18),
                    label: Text(action.label),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextField(
                controller: _question,
                enabled: !isBusy,
                maxLength: AiConstants.maxQuestionChars,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _ask(),
                decoration: InputDecoration(
                  labelText: 'Ask about this passage',
                  hintText: 'e.g. How does this connect to the previous page?',
                  prefixIcon: Icon(SynthesisAction.ask.icon),
                  counterText: '',
                  border: const OutlineInputBorder(),
                  suffixIcon: ListenableBuilder(
                    listenable: _question,
                    builder: (context, _) => IconButton(
                      tooltip: 'Ask',
                      icon: const Icon(Icons.send),
                      onPressed: isBusy || _question.text.trim().isEmpty ? null : _ask,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final question in ContextCard.suggestedQuestions)
                  ActionChip(
                    label: Text(question),
                    visualDensity: VisualDensity.compact,
                    onPressed: isBusy ? null : () => _ask(question),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
