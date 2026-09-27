import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:splitmind/core/theme/app_theme.dart';
import 'package:splitmind/features/ai_notes/domain/entities/ai_note.dart';
import 'package:splitmind/features/ai_notes/domain/entities/synthesis_result.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/delete_note_usecase.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/generate_synthesis_usecase.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/get_cached_notes_usecase.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/restore_note_usecase.dart';
import 'package:splitmind/features/ai_notes/presentation/bloc/ai_notes_bloc.dart';
import 'package:splitmind/features/ai_notes/presentation/widgets/ai_chat_panel.dart';
import 'package:splitmind/features/ai_notes/presentation/widgets/note_card.dart';
import 'package:splitmind/features/workspace/domain/entities/synthesis_action.dart';
import 'package:splitmind/features/workspace/presentation/bloc/active_workspace_bloc.dart';

import '../../helpers/fixtures.dart';

class _MockGenerate extends Mock implements GenerateSynthesisUseCase {}

class _MockGetCached extends Mock implements GetCachedNotesUseCase {}

class _MockDelete extends Mock implements DeleteNoteUseCase {}

class _MockRestore extends Mock implements RestoreNoteUseCase {}

const _flashcards =
    '**Q:** What is spaced repetition?\n**A:** Reviews at growing intervals.\n\n---\n\n'
    '**Q:** Why does it work?\n**A:** Recall strengthens memory.';

void main() {
  setUpAll(() {
    registerFallbackValue(highlightA);
    registerFallbackValue(SynthesisAction.summarize);
    registerFallbackValue(noteFor(highlightA, SynthesisAction.summarize));
  });

  const debounce = Duration(milliseconds: 30);
  late ActiveWorkspaceBloc workspace;
  late _MockGenerate generate;
  late _MockRestore restore;

  // Blocs are created inside the test body so their timers run in
  // testWidgets' fake-async zone.
  Future<void> pumpPanel(WidgetTester tester, {List<AiNote> cached = const []}) async {
    workspace = ActiveWorkspaceBloc();
    generate = _MockGenerate();
    restore = _MockRestore();
    final getCached = _MockGetCached();
    final delete = _MockDelete();
    when(() => getCached()).thenAnswer((_) async => cached);
    when(() => delete(any())).thenAnswer((_) async {});
    when(() => restore(any())).thenAnswer((_) async {});
    when(() => generate(any(), any(), question: any(named: 'question'))).thenAnswer(
      (inv) async =>
          SynthesisResult(note: noteFor(highlightA, inv.positionalArguments[1] as SynthesisAction, id: 'new')),
    );
    final notes = AiNotesBloc(
      activeWorkspaceBloc: workspace,
      generateSynthesisUseCase: generate,
      getCachedNotesUseCase: getCached,
      deleteNoteUseCase: delete,
      restoreNoteUseCase: restore,
      dispatchDebounce: debounce,
    );
    addTearDown(() async {
      await notes.close();
      await workspace.close();
    });

    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: workspace),
          BlocProvider.value(value: notes),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: AiChatPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the passage card offers every quick action and an Ask field', (tester) async {
    await pumpPanel(tester);
    workspace.add(const HighlightSentToAi(highlightA));
    await tester.pumpAndSettle();

    for (final action in SynthesisAction.quickActions) {
      expect(find.widgetWithText(FilledButton, action.label), findsOneWidget, reason: action.label);
    }
    await tester.enterText(find.widgetWithText(TextField, 'Ask about this passage'), 'Why does it work?');
    await tester.pump(); // the send button enables once there is text
    await tester.tap(find.byTooltip('Ask'));
    await tester.pump(debounce * 2);
    await tester.pumpAndSettle();

    verify(() => generate(highlightA, SynthesisAction.ask, question: 'Why does it work?')).called(1);
    expect(find.byType(NoteCard), findsOneWidget);
  });

  testWidgets('a suggested question is sent with one tap', (tester) async {
    await pumpPanel(tester);
    workspace.add(const HighlightSentToAi(highlightA));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Why does this matter?'));
    await tester.pump(debounce * 2);
    await tester.pumpAndSettle();
    verify(() => generate(highlightA, SynthesisAction.ask, question: 'Why does this matter?')).called(1);
  });

  testWidgets('filter chips narrow the notes list by kind', (tester) async {
    await pumpPanel(
      tester,
      cached: [
        noteFor(highlightA, SynthesisAction.explain, id: 'a', at: DateTime.utc(2026, 9, 3)),
        noteFor(highlightB, SynthesisAction.quiz, id: 'b', at: DateTime.utc(2026, 9, 2)),
        noteFor(highlightA, SynthesisAction.explain, id: 'c', at: DateTime.utc(2026, 9, 1)),
      ],
    );
    expect(find.byType(NoteCard), findsNWidgets(3));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Quiz 1'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All 3'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard), findsNWidgets(3));
  });

  testWidgets('flashcard notes hide answers until tapped', (tester) async {
    final base = noteFor(highlightA, SynthesisAction.flashcard);
    await pumpPanel(
      tester,
      cached: [
        AiNote(
          id: base.id,
          action: base.action,
          markdown: _flashcards,
          sourceText: base.sourceText,
          createdAt: base.createdAt,
        ),
      ],
    );
    // AnimatedCrossFade keeps the hidden side in the tree, so only count
    // what can actually be seen and tapped.
    final hint = find.text('Tap to reveal the answer').hitTestable();
    final answer = find.text('Reviews at growing intervals.').hitTestable();
    expect(hint, findsNWidgets(2));
    expect(answer, findsNothing);

    await tester.tap(find.text('What is spaced repetition?'));
    await tester.pumpAndSettle();
    expect(hint, findsOneWidget);
    expect(answer, findsOneWidget);

    await tester.tap(find.text('Show all answers'));
    await tester.pumpAndSettle();
    expect(find.text('Hide answers'), findsOneWidget);
  });

  testWidgets('a deleted note can be brought back with Undo', (tester) async {
    final note = noteFor(highlightA, SynthesisAction.terms, id: 'keep');
    await pumpPanel(tester, cached: [note]);

    await tester.tap(find.byTooltip('Note options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete note'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard), findsOneWidget);
    verify(() => restore(note)).called(1);
  });

  testWidgets("tapping a note's citation asks the reader to show that page", (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPanel(tester, cached: [noteFor(highlightB, SynthesisAction.summarize)]);

    await tester.tap(find.bySemanticsLabel('Go to source, page 3'));
    await tester.pumpAndSettle();
    semantics.dispose();
    expect(workspace.state.pageRequest?.docId, 'doc-1');
    expect(workspace.state.pageRequest?.page, 3);
  });
}
