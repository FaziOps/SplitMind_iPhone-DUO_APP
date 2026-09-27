import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/device/device_posture_cubit.dart';
import '../../../../injection_container.dart';
import '../../../ai_notes/presentation/bloc/ai_notes_bloc.dart';
import '../../../ai_notes/presentation/widgets/ai_chat_panel.dart';
import '../../../reader/presentation/bloc/reader_bloc.dart';
import '../../../reader/presentation/widgets/document_viewer.dart';
import '../bloc/active_workspace_bloc.dart';
import '../widgets/dual_pane_layout.dart';
import '../widgets/floating_overlay.dart';
import '../widgets/posture_simulator_button.dart';
import '../widgets/workspace_layout.dart';

/// Master layout adapting between dual-pane, laptop and single-pane modes.
class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key, this.launchAction = ReaderLaunchAction.none});

  final ReaderLaunchAction launchAction;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Screen-level BLoCs (factories). They sit above every layout, so
        // folding or unfolding never loses the document, selection or notes.
        BlocProvider(create: (_) => sl<ReaderBloc>()..add(ReaderStarted(launchAction: launchAction))),
        BlocProvider(create: (_) => sl<AiNotesBloc>()),
      ],
      child: const _WorkspaceView(),
    );
  }
}

class _WorkspaceView extends StatefulWidget {
  const _WorkspaceView();

  @override
  State<_WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<_WorkspaceView> {
  // GlobalKeys let each pane's element (and the PDF viewer's state) move
  // between layouts instead of being rebuilt from scratch.
  final _readerKey = GlobalKey(debugLabel: 'reader-pane');
  final _notesKey = GlobalKey(debugLabel: 'notes-pane');

  WorkspaceLayoutMode _mode = WorkspaceLayoutMode.single;
  bool _overlayOpen = false;

  void _openOverlay() {
    if (_mode == WorkspaceLayoutMode.single && !_overlayOpen) setState(() => _overlayOpen = true);
  }

  void _closeOverlay() {
    if (_overlayOpen) setState(() => _overlayOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final posture = context.watch<DevicePostureCubit>().state;
    final displayFeatures = MediaQuery.displayFeaturesOf(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<ActiveWorkspaceBloc, ActiveWorkspaceState>(
          // Sending text to AI on a single screen brings the notes panel up.
          listenWhen: (a, b) => (b.aiContext != null && a.aiContext != b.aiContext) || a.lastCommand != b.lastCommand,
          listener: (context, state) => _openOverlay(),
        ),
        BlocListener<ActiveWorkspaceBloc, ActiveWorkspaceState>(
          // Jumping to a note's source page needs the page visible.
          listenWhen: (a, b) => b.pageRequest != null && a.pageRequest != b.pageRequest,
          listener: (context, state) => _closeOverlay(),
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _mode = resolveWorkspaceLayout(
                size: constraints.biggest,
                posture: posture,
                displayFeatures: displayFeatures,
              );
              return switch (_mode) {
                WorkspaceLayoutMode.sideBySide => DualPaneLayout(
                  axis: Axis.horizontal,
                  primary: _reader(),
                  secondary: _notes(),
                ),
                WorkspaceLayoutMode.stacked => DualPaneLayout(
                  axis: Axis.vertical,
                  primary: _reader(),
                  secondary: _notes(),
                ),
                WorkspaceLayoutMode.single => _singlePane(),
              };
            },
          ),
        ),
      ),
    );
  }

  Widget _reader() => KeyedSubtree(
    key: _readerKey,
    child: DocumentViewer(toolbarTrailing: kDebugMode ? const PostureSimulatorButton() : null),
  );

  Widget _notes({ScrollController? controller, VoidCallback? onClose}) => KeyedSubtree(
    key: _notesKey,
    child: AiChatPanel(scrollController: controller, onClose: onClose),
  );

  Widget _singlePane() {
    return Stack(
      children: [
        Positioned.fill(child: _reader()),
        if (_overlayOpen)
          Positioned.fill(
            child: FloatingNotesOverlay(
              onClose: _closeOverlay,
              builder: (context, controller) => _notes(controller: controller, onClose: _closeOverlay),
            ),
          )
        else
          BlocSelector<ReaderBloc, ReaderState, bool>(
            // The selection bar offers the same actions, so the button steps aside.
            selector: (state) => state.selection != null,
            builder: (context, hasSelection) {
              if (hasSelection) return const SizedBox.shrink();
              return Positioned(
                right: 24,
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                child: FloatingActionButton.extended(
                  onPressed: _openOverlay,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('AI Notes'),
                ),
              );
            },
          ),
      ],
    );
  }
}
