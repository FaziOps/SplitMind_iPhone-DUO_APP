import 'package:equatable/equatable.dart';

import 'highlight.dart';

/// The contextual AI actions from FR-4. [name] is the backend wire value.
enum SynthesisAction {
  explain('Explain', 'Explaining'),
  summarize('Summarize', 'Summarizing'),
  flashcard('Flashcards', 'Writing flashcards'),
  simplify('Simplify', 'Simplifying'),
  terms('Key terms', 'Finding key terms'),
  quiz('Quiz', 'Writing a quiz'),
  ask('Ask', 'Answering');

  const SynthesisAction(this.label, this.progressLabel);

  final String label;
  final String progressLabel;

  /// Actions that answer a question the reader types (sent as `question`).
  bool get requiresQuestion => this == ask;

  /// One-tap actions: everything that needs no extra input.
  static List<SynthesisAction> get quickActions => [
    for (final a in values)
      if (!a.requiresQuestion) a,
  ];

  /// The short list offered in the system text-selection menu, which has
  /// little room. The selection bar and notes pane offer the rest.
  static const menuActions = [explain, summarize, flashcard];

  static SynthesisAction? tryParse(String? value) {
    for (final action in values) {
      if (action.name == value) return action;
    }
    return null;
  }
}

/// A request to run [action] on [highlight]. [id] distinguishes two identical
/// requests so the second one is not swallowed as "no change".
class SynthesisCommand extends Equatable {
  const SynthesisCommand({required this.id, required this.action, required this.highlight, this.question});

  final int id;
  final SynthesisAction action;
  final Highlight highlight;

  /// The reader's question, for actions where [SynthesisAction.requiresQuestion].
  final String? question;

  @override
  List<Object?> get props => [id, action, highlight, question];
}
