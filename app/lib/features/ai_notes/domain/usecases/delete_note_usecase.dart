import '../repos/notes_repository.dart';

class DeleteNoteUseCase {
  const DeleteNoteUseCase(this.repository);

  final NotesRepository repository;

  Future<void> call(String id) => repository.deleteNote(id);
}
