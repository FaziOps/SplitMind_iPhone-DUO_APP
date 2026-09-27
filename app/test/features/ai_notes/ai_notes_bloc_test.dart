import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:splitmind/core/error/ai_exceptions.dart';
import 'package:splitmind/features/ai_notes/domain/entities/quota_status.dart';
import 'package:splitmind/features/ai_notes/domain/entities/synthesis_result.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/delete_note_usecase.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/generate_synthesis_usecase.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/get_cached_notes_usecase.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/restore_note_usecase.dart';
import 'package:splitmind/features/ai_notes/presentation/bloc/ai_notes_bloc.dart';
import 'package:splitmind/features/workspace/domain/entities/synthesis_action.dart';
import 'package:splitmind/features/workspace/presentation/bloc/active_workspace_bloc.dart';

import '../../helpers/fixtures.dart';

class _MockGenerate extends Mock implements GenerateSynthesisUseCase {}

class _MockGetCached extends Mock implements GetCachedNotesUseCase {}

class _MockDelete extends Mock implements DeleteNoteUseCase {}

class _MockRestore extends Mock implements RestoreNoteUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(highlightA);
    registerFallbackValue(SynthesisAction.summarize);
    registerFallbackValue(noteFor(highlightA, SynthesisAction.summarize));
  });

  late ActiveWorkspaceBloc workspace;
  late _MockGenerate generate;
  late _MockGetCached getCached;
  late _MockDelete delete;
  late _MockRestore restore;

  const debounce = Duration(milliseconds: 30);
  const quota = QuotaStatus(limit: 200, used: 1, remaining: 199);

  AiNotesBloc build() => AiNotesBloc(
    activeWorkspaceBloc: workspace,
    generateSynthesisUseCase: generate,
    getCachedNotesUseCase: getCached,
    deleteNoteUseCase: delete,
    restoreNoteUseCase: restore,
    dispatchDebounce: debounce,
  );

  Future<void> settle() => Future<void>.delayed(debounce * 3);

  setUp(() {
    workspace = ActiveWorkspaceBloc();
    generate = _MockGenerate();
    getCached = _MockGetCached();
    delete = _MockDelete();
    restore = _MockRestore();
    when(() => getCached()).thenAnswer((_) async => []);
    when(() => delete(any())).thenAnswer((_) async {});
    when(() => restore(any())).thenAnswer((_) async {});
    when(() => generate(any(), any())).thenAnswer(
      (inv) async => SynthesisResult(
        note: noteFor(inv.positionalArguments[0], inv.positionalArguments[1], id: 'n-${inv.positionalArguments[1]}'),
        quota: quota,
      ),
    );
  });

  tearDown(() => workspace.close());

  test('restores cached notes on boot (FR-6)', () async {
    final cached = noteFor(highlightA, SynthesisAction.explain, id: 'cached');
    when(() => getCached()).thenAnswer((_) async => [cached]);
    final bloc = build();
    await pumpEventQueue();
    expect(bloc.state.status, AiNotesStatus.ready);
    expect(bloc.state.notes, [cached]);
    await bloc.close();
  });

  test('a mediator command shows as pending at once, then produces a note', () async {
    final bloc = build();
    await pumpEventQueue();

    workspace.add(const SynthesisRequested(SynthesisAction.summarize, highlightA));
    await pumpEventQueue();
    expect(bloc.state.context, highlightA);
    expect(bloc.state.pending?.action, SynthesisAction.summarize);
    verifyNever(() => generate(any(), any()));

    await settle();
    expect(bloc.state.pending, isNull);
    expect(bloc.state.notes.single.action, SynthesisAction.summarize);
    expect(bloc.state.quota, quota);
    await bloc.close();
  });

  test('rapid requests are debounced so only the last is sent (NFR-5)', () async {
    final bloc = build();
    await pumpEventQueue();

    bloc
      ..add(const GenerateRequested(SynthesisAction.explain, highlight: highlightA))
      ..add(const GenerateRequested(SynthesisAction.summarize, highlight: highlightA))
      ..add(const GenerateRequested(SynthesisAction.flashcard, highlight: highlightB));
    await settle();

    verify(() => generate(highlightB, SynthesisAction.flashcard)).called(1);
    verifyNoMoreInteractions(generate);
    expect(bloc.state.notes, hasLength(1));
    await bloc.close();
  });

  test('highlighting alone never calls the AI', () async {
    final bloc = build();
    workspace.add(const TextHighlighted(highlightA));
    await settle();
    verifyNever(() => generate(any(), any()));
    await bloc.close();
  });

  test('failures surface as typed state and can be retried (FR-11)', () async {
    var calls = 0;
    when(() => generate(any(), any())).thenAnswer((_) async {
      if (calls++ == 0) throw const NetworkException();
      return SynthesisResult(note: noteFor(highlightA, SynthesisAction.explain));
    });
    final bloc = build();
    await pumpEventQueue();

    bloc.add(const GenerateRequested(SynthesisAction.explain, highlight: highlightA));
    await settle();
    expect(bloc.state.failure, isA<NetworkException>());
    expect(bloc.state.pending, isNull);

    bloc.add(const RetryRequested());
    await settle();
    expect(bloc.state.failure, isNull);
    expect(bloc.state.notes, hasLength(1));
    await bloc.close();
  });

  test('quota exhaustion zeroes the remaining count', () async {
    final bloc = build();
    await pumpEventQueue();
    bloc.add(const GenerateRequested(SynthesisAction.explain, highlight: highlightA));
    await settle();

    when(() => generate(any(), any())).thenThrow(const QuotaExceededException());
    bloc.add(const GenerateRequested(SynthesisAction.summarize, highlight: highlightB));
    await settle();
    expect(bloc.state.failure, isA<QuotaExceededException>());
    expect(bloc.state.quota?.remaining, 0);
    await bloc.close();
  });

  test('does not replay a command issued before the bloc existed', () async {
    workspace.add(const SynthesisRequested(SynthesisAction.explain, highlightA));
    await pumpEventQueue();
    final bloc = build();
    await settle();
    verifyNever(() => generate(any(), any()));
    expect(bloc.state.context, highlightA);
    await bloc.close();
  });

  test('dismissing the context clears it through the mediator', () async {
    final bloc = build();
    workspace.add(const HighlightSentToAi(highlightA));
    await pumpEventQueue();
    expect(bloc.state.context, highlightA);

    bloc.add(const ContextDismissed());
    await pumpEventQueue();
    expect(workspace.state.aiContext, isNull);
    expect(bloc.state.context, isNull);
    await bloc.close();
  });

  test('deleting a note removes it from state and the cache', () async {
    final cached = noteFor(highlightA, SynthesisAction.explain, id: 'gone');
    when(() => getCached()).thenAnswer((_) async => [cached]);
    final bloc = build();
    await pumpEventQueue();
    bloc.add(const NoteDeleted('gone'));
    await pumpEventQueue();
    expect(bloc.state.notes, isEmpty);
    verify(() => delete('gone')).called(1);
    await bloc.close();
  });

  test('ask sends the question, shows it while pending, and keeps it for retry', () async {
    var calls = 0;
    when(() => generate(any(), any(), question: any(named: 'question'))).thenAnswer((_) async {
      if (calls++ == 0) throw const NetworkException();
      return SynthesisResult(note: noteFor(highlightA, SynthesisAction.ask));
    });
    final bloc = build();
    workspace.add(const HighlightSentToAi(highlightA));
    await pumpEventQueue();

    bloc.add(const GenerateRequested(SynthesisAction.ask, question: 'Why does it work?'));
    await pumpEventQueue();
    expect(bloc.state.pending?.question, 'Why does it work?');
    await settle();
    expect(bloc.state.failure, isA<NetworkException>());

    bloc.add(const RetryRequested());
    await settle();
    verify(() => generate(highlightA, SynthesisAction.ask, question: 'Why does it work?')).called(2);
    expect(bloc.state.notes, hasLength(1));
    await bloc.close();
  });

  test('undo puts a deleted note back in its original place', () async {
    final newer = noteFor(highlightB, SynthesisAction.quiz, id: 'newer', at: DateTime.utc(2026, 9, 3));
    final middle = noteFor(highlightA, SynthesisAction.explain, id: 'middle', at: DateTime.utc(2026, 9, 2));
    final older = noteFor(highlightA, SynthesisAction.terms, id: 'older', at: DateTime.utc(2026, 9, 1));
    when(() => getCached()).thenAnswer((_) async => [newer, middle, older]);
    final bloc = build();
    await pumpEventQueue();

    bloc.add(const NoteDeleted('middle'));
    await pumpEventQueue();
    expect(bloc.state.notes.map((n) => n.id), ['newer', 'older']);

    bloc.add(NoteRestored(middle));
    await pumpEventQueue();
    expect(bloc.state.notes.map((n) => n.id), ['newer', 'middle', 'older']);
    verify(() => restore(middle)).called(1);
    await bloc.close();
  });
}
