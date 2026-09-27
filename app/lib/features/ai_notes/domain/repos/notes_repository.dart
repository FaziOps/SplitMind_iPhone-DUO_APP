import '../../../workspace/domain/entities/highlight.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../entities/ai_note.dart';
import '../entities/synthesis_result.dart';

/// Repository pattern (PRD Section 3): the presentation layer never knows
/// whether notes come from the backend proxy, Hive, or (later) Firebase.
abstract class NotesRepository {
  /// Runs [action] on [highlight] through the backend proxy and caches the
  /// resulting note locally. Throws an AiRequestException on failure.
  /// [question] is required when [SynthesisAction.requiresQuestion].
  Future<SynthesisResult> synthesize(Highlight highlight, SynthesisAction action, {String? question});

  /// Cached notes, newest first (FR-6).
  Future<List<AiNote>> getCachedNotes();

  Future<void> deleteNote(String id);

  /// Puts a deleted note back (undo).
  Future<void> restoreNote(AiNote note);
}
