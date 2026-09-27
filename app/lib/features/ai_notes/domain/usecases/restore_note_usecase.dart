import '../entities/ai_note.dart';
import '../repos/notes_repository.dart';

class RestoreNoteUseCase {
  const RestoreNoteUseCase(this.repository);

  final NotesRepository repository;

  Future<void> call(AiNote note) => repository.restoreNote(note);
}
