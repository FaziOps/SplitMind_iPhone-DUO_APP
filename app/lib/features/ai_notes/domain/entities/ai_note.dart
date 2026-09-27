import 'package:equatable/equatable.dart';

import '../../../workspace/domain/entities/synthesis_action.dart';

/// An AI-generated note (PRD v1: AiResponse), with a link back to the exact
/// source passage and document (FR-8).
class AiNote extends Equatable {
  const AiNote({
    required this.id,
    required this.action,
    required this.markdown,
    required this.sourceText,
    required this.createdAt,
    this.sourceDocId,
    this.sourceDocTitle,
    this.sourcePage,
    this.question,
  });

  final String id;
  final SynthesisAction action;

  /// Structured Markdown from the backend (DR-2).
  final String markdown;
  final String sourceText;
  final String? sourceDocId;
  final String? sourceDocTitle;
  final int? sourcePage;
  final DateTime createdAt;

  /// What the reader asked, for [SynthesisAction.ask] notes.
  final String? question;

  @override
  List<Object?> get props => [
    id,
    action,
    markdown,
    sourceText,
    sourceDocId,
    sourceDocTitle,
    sourcePage,
    createdAt,
    question,
  ];
}
