import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:splitmind/core/device/device_posture.dart';
import 'package:splitmind/core/device/device_posture_cubit.dart';
import 'package:splitmind/core/device/foldable_device_adapter.dart';
import 'package:splitmind/core/theme/app_theme.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/delete_note_usecase.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/generate_synthesis_usecase.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/get_cached_notes_usecase.dart';
import 'package:splitmind/features/ai_notes/domain/usecases/restore_note_usecase.dart';
import 'package:splitmind/features/ai_notes/presentation/bloc/ai_notes_bloc.dart';
import 'package:splitmind/features/ai_notes/presentation/widgets/ai_chat_panel.dart';
import 'package:splitmind/features/reader/domain/repos/document_repository.dart';
import 'package:splitmind/features/reader/presentation/bloc/reader_bloc.dart';
import 'package:splitmind/features/workspace/presentation/bloc/active_workspace_bloc.dart';
import 'package:splitmind/features/workspace/presentation/pages/workspace_screen.dart';
import 'package:splitmind/injection_container.dart';

import '../../helpers/fixtures.dart';

class _MockRepo extends Mock implements DocumentRepository {}

class _MockGenerate extends Mock implements GenerateSynthesisUseCase {}

class _MockGetCached extends Mock implements GetCachedNotesUseCase {}

class _MockDelete extends Mock implements DeleteNoteUseCase {}

class _MockRestore extends Mock implements RestoreNoteUseCase {}

void main() {
  late ActiveWorkspaceBloc workspace;
  late SimulatedFoldableDeviceAdapter adapter;
  late DevicePostureCubit posture;

  // Everything stream-based is created inside the test body so it runs in
  // testWidgets' fake-async zone and flushes on pump.
  Future<void> pumpAt(WidgetTester tester, Size size) async {
    await sl.reset();
    workspace = ActiveWorkspaceBloc();
    adapter = SimulatedFoldableDeviceAdapter();
    posture = DevicePostureCubit(adapter);
    final repo = _MockRepo();
    when(() => repo.getActiveDocument()).thenAnswer((_) async => null);
    final getCached = _MockGetCached();
    when(() => getCached()).thenAnswer((_) async => []);
    sl
      ..registerSingleton(workspace)
      ..registerFactory(() => ReaderBloc(activeWorkspaceBloc: workspace, documentRepository: repo))
      ..registerFactory(
        () => AiNotesBloc(
          activeWorkspaceBloc: workspace,
          generateSynthesisUseCase: _MockGenerate(),
          getCachedNotesUseCase: getCached,
          deleteNoteUseCase: _MockDelete(),
          restoreNoteUseCase: _MockRestore(),
        ),
      );
    addTearDown(() async {
      await posture.close();
      await workspace.close();
    });

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: workspace),
          BlocProvider.value(value: posture),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const WorkspaceScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('standard iPhone: reader with an AI Notes button, notes hidden', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    expect(find.text('Open a document to start'), findsOneWidget);
    expect(find.byType(AiChatPanel), findsNothing);
    expect(find.widgetWithText(FloatingActionButton, 'AI Notes'), findsOneWidget);

    await tester.tap(find.text('AI Notes'));
    await tester.pumpAndSettle();
    expect(find.byType(AiChatPanel), findsOneWidget);
    expect(find.text('No notes yet'), findsOneWidget);
  });

  testWidgets('sending text to AI on a single screen opens the overlay', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    workspace.add(const HighlightSentToAi(highlightA));
    await tester.pumpAndSettle();
    expect(find.byType(AiChatPanel), findsOneWidget);
    expect(find.text(highlightA.text), findsOneWidget);
  });

  testWidgets('unfolded: both panes side by side, and notes survive a fold', (tester) async {
    await pumpAt(tester, const Size(800, 900));
    expect(find.byType(AiChatPanel), findsOneWidget);
    expect(find.byType(VerticalDivider), findsOneWidget);

    workspace.add(const HighlightSentToAi(highlightA));
    await tester.pumpAndSettle();

    // Fold to the outer display: the context is still there when reopened.
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(AiChatPanel), findsNothing);
    await tester.tap(find.text('AI Notes'));
    await tester.pumpAndSettle();
    expect(find.text(highlightA.text), findsOneWidget);
  });

  testWidgets('laptop mode stacks reader over notes (FR-2)', (tester) async {
    await pumpAt(tester, const Size(800, 900));
    adapter.emit(DevicePosture.fromHingeAngle(110));
    await tester.pumpAndSettle();

    final reader = tester.getRect(find.text('Open a document to start'));
    final notes = tester.getRect(find.byType(AiChatPanel));
    expect(reader.center.dy, lessThan(notes.top));
    expect(find.byType(VerticalDivider), findsNothing);
  });
}
