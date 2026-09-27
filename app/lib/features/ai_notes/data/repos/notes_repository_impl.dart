import 'package:uuid/uuid.dart';

import '../../../workspace/domain/entities/highlight.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../domain/entities/ai_note.dart';
import '../../domain/entities/synthesis_result.dart';
import '../../domain/repos/notes_repository.dart';
import '../models/note_model.dart';
import '../sources/backend_proxy_data_source.dart';
import '../sources/notes_local_data_source.dart';

/// The corrected repository from PRD Section 3, 4a: remote calls go to the
/// backend proxy, and every result is cached in Hive before it is returned.
class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl(this._remote, this._local, {Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? DateTime.now;

  final BackendProxyDataSource _remote;
  final NotesLocalDataSource _local;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<SynthesisResult> synthesize(Highlight highlight, SynthesisAction action, {String? question}) async {
    final response = await _remote.synthesize(
      text: highlight.text,
      action: action,
      question: question,
      docId: highlight.docId,
      page: highlight.pageNumber,
    );
    final note = AiNote(
      id: _uuid.v4(),
      action: action,
      markdown: response.markdown,
      sourceText: highlight.text,
      sourceDocId: highlight.docId,
      sourceDocTitle: highlight.docTitle,
      sourcePage: highlight.pageNumber,
      createdAt: _clock(),
      question: question,
    );
    await _local.cacheNote(NoteModel.fromEntity(note));
    return SynthesisResult(note: note, quota: response.quota);
  }

  @override
  Future<List<AiNote>> getCachedNotes() async {
    final models = await _local.getNotes();
    return [for (final model in models) model.toEntity()];
  }

  @override
  Future<void> deleteNote(String id) => _local.deleteNote(id);

  @override
  Future<void> restoreNote(AiNote note) => _local.cacheNote(NoteModel.fromEntity(note));
}
