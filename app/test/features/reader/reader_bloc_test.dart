import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:splitmind/features/reader/domain/entities/reader_document.dart';
import 'package:splitmind/features/reader/domain/repos/document_repository.dart';
import 'package:splitmind/features/reader/presentation/bloc/reader_bloc.dart';
import 'package:splitmind/features/workspace/domain/entities/synthesis_action.dart';
import 'package:splitmind/features/workspace/presentation/bloc/active_workspace_bloc.dart';

import '../../helpers/fixtures.dart';

class _MockRepo extends Mock implements DocumentRepository {}

void main() {
  late ActiveWorkspaceBloc workspace;
  late _MockRepo repo;
  final doc = ReaderDocument(
    id: 'doc-1',
    title: 'Memory',
    filePath: '/tmp/doc-1.pdf',
    lastPage: 4,
    importedAt: DateTime.utc(2026, 9, 1),
  );

  ReaderBloc build() => ReaderBloc(activeWorkspaceBloc: workspace, documentRepository: repo);

  setUp(() {
    workspace = ActiveWorkspaceBloc();
    repo = _MockRepo();
    when(() => repo.getActiveDocument()).thenAnswer((_) async => null);
    when(
      () => repo.saveReadingPosition(
        any(),
        page: any(named: 'page'),
        pageCount: any(named: 'pageCount'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() => workspace.close());

  test('restores the last document at its last page (FR-6)', () async {
    when(() => repo.getActiveDocument()).thenAnswer((_) async => doc);
    final bloc = build()..add(const ReaderStarted());
    await pumpEventQueue();
    expect(bloc.state.status, ReaderStatus.ready);
    expect(bloc.state.currentPage, 4);
    await bloc.close();
  });

  test('shows the empty state when nothing was open (FR-11)', () async {
    final bloc = build()..add(const ReaderStarted());
    await pumpEventQueue();
    expect(bloc.state.status, ReaderStatus.empty);
    await bloc.close();
  });

  test('a failed first import shows an error, a cancelled one does not', () async {
    when(() => repo.pickAndImport()).thenAnswer((_) async => null);
    final bloc = build()..add(const ReaderStarted(launchAction: ReaderLaunchAction.importPdf));
    await pumpEventQueue();
    expect(bloc.state.status, ReaderStatus.empty);

    when(() => repo.pickAndImport()).thenThrow(const DocumentImportException('Bad file'));
    bloc.add(const ReaderImportRequested());
    await pumpEventQueue();
    expect(bloc.state.status, ReaderStatus.failure);
    expect(bloc.state.message, 'Bad file');
    await bloc.close();
  });

  test('selection changes flow to the mediator, not to the notes pane', () async {
    final bloc = build();
    bloc.add(const ReaderSelectionChanged(highlightA));
    await pumpEventQueue();
    expect(workspace.state.activeHighlight, highlightA);

    bloc.add(const ReaderSelectionChanged(null));
    await pumpEventQueue();
    expect(workspace.state.activeHighlight, isNull);
    await bloc.close();
  });

  test('send-to-AI and quick actions become mediator events (FR-3a, FR-4)', () async {
    final bloc = build();
    bloc.add(const ReaderSendToAi(highlightA));
    await pumpEventQueue();
    expect(workspace.state.aiContext, highlightA);
    expect(workspace.state.lastCommand, isNull);

    bloc.add(const ReaderSendToAi(highlightB, action: SynthesisAction.flashcard));
    await pumpEventQueue();
    expect(workspace.state.lastCommand?.action, SynthesisAction.flashcard);
    expect(workspace.state.lastCommand?.highlight, highlightB);
    await bloc.close();
  });

  test('page changes are persisted', () async {
    when(() => repo.getActiveDocument()).thenAnswer((_) async => doc);
    final bloc = build()..add(const ReaderStarted());
    await pumpEventQueue();
    bloc.add(const ReaderPageChanged(9, pageCount: 20));
    await pumpEventQueue();
    expect(bloc.state.currentPage, 9);
    verify(() => repo.saveReadingPosition('doc-1', page: 9, pageCount: 20)).called(1);
    await bloc.close();
  });
}
