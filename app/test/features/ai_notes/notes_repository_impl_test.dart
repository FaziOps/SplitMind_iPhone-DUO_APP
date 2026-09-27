import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:splitmind/core/error/ai_exceptions.dart';
import 'package:splitmind/features/ai_notes/data/models/note_model.dart';
import 'package:splitmind/features/ai_notes/data/models/synthesis_response_model.dart';
import 'package:splitmind/features/ai_notes/data/repos/notes_repository_impl.dart';
import 'package:splitmind/features/ai_notes/data/sources/backend_proxy_data_source.dart';
import 'package:splitmind/features/ai_notes/data/sources/notes_local_data_source.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/generate_synthesis_usecase.dart';
import 'package:splitmind/features/workspace/domain/entities/highlight.dart';
import 'package:splitmind/features/workspace/domain/entities/synthesis_action.dart';

import '../../helpers/fixtures.dart';

class _MockRemote extends Mock implements BackendProxyDataSource {}

class _MemoryLocal implements NotesLocalDataSource {
  final notes = <String, NoteModel>{};

  @override
  Future<void> cacheNote(NoteModel note) async => notes[note.id] = note;

  @override
  Future<void> deleteNote(String id) async => notes.remove(id);

  @override
  Future<List<NoteModel>> getNotes() async => notes.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

void main() {
  setUpAll(() => registerFallbackValue(SynthesisAction.summarize));

  late _MockRemote remote;
  late _MemoryLocal local;
  late NotesRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    local = _MemoryLocal();
    repo = NotesRepositoryImpl(remote, local, clock: () => DateTime.utc(2026, 9, 26));
  });

  test('sends provenance to the proxy and caches the note with its citation (FR-8)', () async {
    when(
      () => remote.synthesize(
        text: any(named: 'text'),
        action: any(named: 'action'),
        docId: any(named: 'docId'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => const SynthesisResponseModel(markdown: '### Summary\n- ok'));

    final result = await repo.synthesize(highlightA, SynthesisAction.summarize);

    verify(() => remote.synthesize(text: highlightA.text, action: SynthesisAction.summarize, docId: 'doc-1', page: 2));
    expect(result.note.sourcePage, 2);
    expect(result.note.sourceDocTitle, 'Memory');
    final cached = await repo.getCachedNotes();
    expect(cached.single, result.note);
  });

  test('nothing is cached when the proxy fails', () async {
    when(
      () => remote.synthesize(
        text: any(named: 'text'),
        action: any(named: 'action'),
        docId: any(named: 'docId'),
        page: any(named: 'page'),
      ),
    ).thenThrow(const SafetyBlockedException());

    await expectLater(repo.synthesize(highlightA, SynthesisAction.explain), throwsA(isA<SafetyBlockedException>()));
    expect(local.notes, isEmpty);
  });

  test('use case rejects empty and oversized passages before any network call', () async {
    final useCase = GenerateSynthesisUseCase(repo);
    expect(
      () => useCase(const Highlight(text: '   '), SynthesisAction.explain),
      throwsA(isA<InvalidRequestException>()),
    );
    expect(
      () => useCase(Highlight(text: 'x' * 8001), SynthesisAction.explain),
      throwsA(isA<InvalidRequestException>()),
    );
    verifyZeroInteractions(remote);
  });

  test('ask sends the question and keeps it on the cached note; restore re-caches', () async {
    when(
      () => remote.synthesize(
        text: any(named: 'text'),
        action: any(named: 'action'),
        question: any(named: 'question'),
        docId: any(named: 'docId'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => const SynthesisResponseModel(markdown: '### Answer\nok'));

    final result = await GenerateSynthesisUseCase(repo)(
      highlightA,
      SynthesisAction.ask,
      question: '  Why does it work?  ',
    );

    verify(
      () => remote.synthesize(
        text: highlightA.text,
        action: SynthesisAction.ask,
        question: 'Why does it work?',
        docId: 'doc-1',
        page: 2,
      ),
    );
    expect(result.note.question, 'Why does it work?');

    await repo.deleteNote(result.note.id);
    await repo.restoreNote(result.note);
    expect((await repo.getCachedNotes()).single, result.note);
  });

  test('ask needs a question of a sensible length; other actions ignore it', () {
    final useCase = GenerateSynthesisUseCase(repo);
    expect(() => useCase(highlightA, SynthesisAction.ask), throwsA(isA<InvalidRequestException>()));
    expect(() => useCase(highlightA, SynthesisAction.ask, question: '   '), throwsA(isA<InvalidRequestException>()));
    expect(
      () => useCase(highlightA, SynthesisAction.ask, question: 'x' * 501),
      throwsA(isA<InvalidRequestException>()),
    );

    when(
      () => remote.synthesize(
        text: any(named: 'text'),
        action: any(named: 'action'),
        docId: any(named: 'docId'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => const SynthesisResponseModel(markdown: '### Quiz\nok'));
    return expectLater(
      useCase(highlightA, SynthesisAction.quiz, question: 'ignored').then((r) => r.note.question),
      completion(isNull),
    );
  });
}
