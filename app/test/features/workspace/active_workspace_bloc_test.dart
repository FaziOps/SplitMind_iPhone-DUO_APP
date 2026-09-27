import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitmind/features/workspace/domain/entities/synthesis_action.dart';
import 'package:splitmind/features/workspace/presentation/bloc/active_workspace_bloc.dart';

import '../../helpers/fixtures.dart';

void main() {
  group('ActiveWorkspaceBloc (mediator)', () {
    blocTest<ActiveWorkspaceBloc, ActiveWorkspaceState>(
      'tracks and clears the live highlight',
      build: ActiveWorkspaceBloc.new,
      act: (bloc) => bloc
        ..add(const TextHighlighted(highlightA))
        ..add(const HighlightCleared()),
      expect: () => const [ActiveWorkspaceState(activeHighlight: highlightA), ActiveWorkspaceState()],
    );

    blocTest<ActiveWorkspaceBloc, ActiveWorkspaceState>(
      'send-to-AI sets the AI context without issuing a command',
      build: ActiveWorkspaceBloc.new,
      act: (bloc) => bloc.add(const HighlightSentToAi(highlightA)),
      expect: () => const [ActiveWorkspaceState(aiContext: highlightA)],
    );

    blocTest<ActiveWorkspaceBloc, ActiveWorkspaceState>(
      'identical synthesis requests get distinct command ids',
      build: ActiveWorkspaceBloc.new,
      act: (bloc) => bloc
        ..add(const SynthesisRequested(SynthesisAction.explain, highlightA))
        ..add(const SynthesisRequested(SynthesisAction.explain, highlightA)),
      verify: (bloc) {
        expect(bloc.state.lastCommand?.id, 2);
        expect(bloc.state.aiContext, highlightA);
      },
    );

    blocTest<ActiveWorkspaceBloc, ActiveWorkspaceState>(
      'clearing the AI context keeps the live highlight',
      build: ActiveWorkspaceBloc.new,
      seed: () => const ActiveWorkspaceState(activeHighlight: highlightB, aiContext: highlightA),
      act: (bloc) => bloc.add(const AiContextCleared()),
      expect: () => const [ActiveWorkspaceState(activeHighlight: highlightB)],
    );
  });

  test('every source-page request is distinct, even for the same page', () async {
    final bloc = ActiveWorkspaceBloc();
    bloc
      ..add(const SourcePageRequested(docId: 'doc-1', page: 3))
      ..add(const SourcePageRequested(docId: 'doc-1', page: 3));
    await pumpEventQueue();
    expect(bloc.state.pageRequest, const PageRequest(id: 2, docId: 'doc-1', page: 3));
    await bloc.close();
  });
}
