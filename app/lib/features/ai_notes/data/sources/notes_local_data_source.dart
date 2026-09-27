import 'package:hive_ce/hive.dart';

import '../models/note_model.dart';

abstract class NotesLocalDataSource {
  Future<void> cacheNote(NoteModel note);

  /// All cached notes, newest first.
  Future<List<NoteModel>> getNotes();

  Future<void> deleteNote(String id);
}

class NotesLocalDataSourceImpl implements NotesLocalDataSource {
  const NotesLocalDataSourceImpl(this.box);

  final Box<NoteModel> box;

  @override
  Future<void> cacheNote(NoteModel note) async {
    await box.put(note.id, note);
    // Hive writes are buffered; flush so a note survives an immediate kill.
    await box.flush();
  }

  @override
  Future<List<NoteModel>> getNotes() async {
    return box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> deleteNote(String id) => box.delete(id);
}
