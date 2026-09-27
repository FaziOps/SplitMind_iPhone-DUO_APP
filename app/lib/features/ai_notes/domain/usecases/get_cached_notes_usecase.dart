import '../entities/ai_note.dart';
import '../repos/notes_repository.dart';

class GetCachedNotesUseCase {
  const GetCachedNotesUseCase(this.repository);

  final NotesRepository repository;

  Future<List<AiNote>> call() => repository.getCachedNotes();
}
