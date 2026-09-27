import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/ai_exceptions.dart';
import '../../../../core/utils/event_transformers.dart';
import '../../../workspace/domain/entities/highlight.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../../workspace/presentation/bloc/active_workspace_bloc.dart';
import '../../domain/entities/ai_note.dart';
import '../../domain/entities/quota_status.dart';
import '../../domain/usecases/delete_note_usecase.dart';
import '../../domain/usecases/generate_synthesis_usecase.dart';
import '../../domain/usecases/get_cached_notes_usecase.dart';
import '../../domain/usecases/restore_note_usecase.dart';

// --- EVENTS ---
sealed class AiNotesEvent {
  const AiNotesEvent();
}

/// Loads cached notes so a force-closed app reopens where it left off (FR-6).
class RestoreCachedWorkspace extends AiNotesEvent {
  const RestoreCachedWorkspace();
}

/// Run [action] on [highlight], or on the current context when omitted.
/// [question] is what the reader typed, for [SynthesisAction.ask].
class GenerateRequested extends AiNotesEvent {
  const GenerateRequested(this.action, {this.highlight, this.question});

  final SynthesisAction action;
  final Highlight? highlight;
  final String? question;
}

class RetryRequested extends AiNotesEvent {
  const RetryRequested();
}

class NoteDeleted extends AiNotesEvent {
  const NoteDeleted(this.id);

  final String id;
}

/// Undo for [NoteDeleted]: puts the note back in its original place.
class NoteRestored extends AiNotesEvent {
  const NoteRestored(this.note);

  final AiNote note;
}

class ContextDismissed extends AiNotesEvent {
  const ContextDismissed();
}

class FailureDismissed extends AiNotesEvent {
  const FailureDismissed();
}

class _WorkspaceChanged extends AiNotesEvent {
  const _WorkspaceChanged(this.workspace);

  final ActiveWorkspaceState workspace;
}

class _DispatchRequested extends AiNotesEvent {
  const _DispatchRequested(this.command);

  final SynthesisCommand command;
}

// --- STATE ---
enum AiNotesStatus { restoring, ready }

class AiNotesState extends Equatable {
  const AiNotesState({
    this.status = AiNotesStatus.restoring,
    this.notes = const [],
    this.context,
    this.pending,
    this.failure,
    this.failedCommand,
    this.quota,
  });

  final AiNotesStatus status;

  /// Newest first.
  final List<AiNote> notes;

  /// The passage sent to this pane, awaiting an action.
  final Highlight? context;

  /// The latest request that has not finished yet.
  final SynthesisCommand? pending;

  final AiRequestException? failure;
  final SynthesisCommand? failedCommand;
  final QuotaStatus? quota;

  bool get isGenerating => pending != null;

  AiNotesState copyWith({
    AiNotesStatus? status,
    List<AiNote>? notes,
    Highlight? Function()? context,
    SynthesisCommand? Function()? pending,
    AiRequestException? Function()? failure,
    SynthesisCommand? Function()? failedCommand,
    QuotaStatus? quota,
  }) {
    return AiNotesState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      context: context != null ? context() : this.context,
      pending: pending != null ? pending() : this.pending,
      failure: failure != null ? failure() : this.failure,
      failedCommand: failedCommand != null ? failedCommand() : this.failedCommand,
      quota: quota ?? this.quota,
    );
  }

  @override
  List<Object?> get props => [status, notes, context, pending, failure, failedCommand, quota];
}

// --- BLOC ---
/// The right pane's BLoC. It observes the Mediator ([ActiveWorkspaceBloc]) and
/// never references the reader.
///
/// NFR-1 / NFR-5: a request shows as pending immediately, but the network call
/// is debounced so only the last request in a burst is sent. Dispatch is
/// sequential, so a request that is already in flight always completes.
class AiNotesBloc extends Bloc<AiNotesEvent, AiNotesState> {
  AiNotesBloc({
    required this.activeWorkspaceBloc,
    required this.generateSynthesisUseCase,
    required this.getCachedNotesUseCase,
    required this.deleteNoteUseCase,
    required this.restoreNoteUseCase,
    Duration dispatchDebounce = AiConstants.dispatchDebounce,
  }) : super(AiNotesState(context: activeWorkspaceBloc.state.aiContext)) {
    // Don't replay a command that was issued before this bloc existed.
    _lastSeenCommandId = activeWorkspaceBloc.state.lastCommand?.id;

    on<RestoreCachedWorkspace>(_onRestore);
    on<_WorkspaceChanged>(_onWorkspaceChanged);
    on<GenerateRequested>(_onGenerateRequested);
    on<_DispatchRequested>(_onDispatch, transformer: debounceSequential(dispatchDebounce));
    on<RetryRequested>(_onRetry);
    on<NoteDeleted>(_onNoteDeleted);
    on<NoteRestored>(_onNoteRestored);
    on<ContextDismissed>((event, emit) => activeWorkspaceBloc.add(const AiContextCleared()));
    on<FailureDismissed>((event, emit) => emit(state.copyWith(failure: () => null, failedCommand: () => null)));

    // 1. Listen to the Mediator BLoC.
    _workspaceSubscription = activeWorkspaceBloc.stream.listen((ws) => add(_WorkspaceChanged(ws)));

    // 2. Check for cached notes on boot.
    add(const RestoreCachedWorkspace());
  }

  final ActiveWorkspaceBloc activeWorkspaceBloc;
  final GenerateSynthesisUseCase generateSynthesisUseCase;
  final GetCachedNotesUseCase getCachedNotesUseCase;
  final DeleteNoteUseCase deleteNoteUseCase;
  final RestoreNoteUseCase restoreNoteUseCase;

  late final StreamSubscription<ActiveWorkspaceState> _workspaceSubscription;
  int? _lastSeenCommandId;
  int _nextCommandId = 1;

  Future<void> _onRestore(RestoreCachedWorkspace event, Emitter<AiNotesState> emit) async {
    try {
      final cached = await getCachedNotesUseCase();
      // Keep anything generated while the cache was loading.
      final known = {for (final n in state.notes) n.id};
      emit(
        state.copyWith(
          status: AiNotesStatus.ready,
          notes: [...state.notes, ...cached.where((n) => !known.contains(n.id))],
        ),
      );
    } catch (_) {
      // A corrupt cache must not block the pane; start empty instead.
      emit(state.copyWith(status: AiNotesStatus.ready));
    }
  }

  void _onWorkspaceChanged(_WorkspaceChanged event, Emitter<AiNotesState> emit) {
    final ws = event.workspace;
    if (ws.aiContext != state.context) {
      emit(state.copyWith(context: () => ws.aiContext));
    }
    final command = ws.lastCommand;
    if (command != null && command.id != _lastSeenCommandId) {
      _lastSeenCommandId = command.id;
      add(GenerateRequested(command.action, highlight: command.highlight, question: command.question));
    }
  }

  void _onGenerateRequested(GenerateRequested event, Emitter<AiNotesState> emit) {
    final highlight = event.highlight ?? state.context;
    if (highlight == null) return;
    final command = SynthesisCommand(
      id: _nextCommandId++,
      action: event.action,
      highlight: highlight,
      question: event.question,
    );
    emit(state.copyWith(pending: () => command, failure: () => null, failedCommand: () => null));
    add(_DispatchRequested(command));
  }

  Future<void> _onDispatch(_DispatchRequested event, Emitter<AiNotesState> emit) async {
    final command = event.command;
    // A newer request replaced this one before the debounce window elapsed.
    if (state.pending != command) return;

    try {
      final result = await generateSynthesisUseCase(command.highlight, command.action, question: command.question);
      emit(
        state.copyWith(
          notes: [result.note, ...state.notes],
          quota: result.quota,
          pending: state.pending == command ? () => null : null,
        ),
      );
    } on AiRequestException catch (e) {
      emit(
        state.copyWith(
          failure: () => e,
          failedCommand: () => command,
          pending: state.pending == command ? () => null : null,
          quota: e is QuotaExceededException && state.quota != null
              ? QuotaStatus(limit: state.quota!.limit, used: state.quota!.limit, remaining: 0, resetsAt: e.resetsAt)
              : null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          failure: () => const ServerException('Something went wrong generating this note.'),
          failedCommand: () => command,
          pending: state.pending == command ? () => null : null,
        ),
      );
    }
  }

  void _onRetry(RetryRequested event, Emitter<AiNotesState> emit) {
    final failed = state.failedCommand;
    if (failed == null) return;
    add(GenerateRequested(failed.action, highlight: failed.highlight, question: failed.question));
  }

  Future<void> _onNoteDeleted(NoteDeleted event, Emitter<AiNotesState> emit) async {
    emit(
      state.copyWith(
        notes: [
          for (final n in state.notes)
            if (n.id != event.id) n,
        ],
      ),
    );
    await deleteNoteUseCase(event.id);
  }

  Future<void> _onNoteRestored(NoteRestored event, Emitter<AiNotesState> emit) async {
    final note = event.note;
    if (state.notes.any((n) => n.id == note.id)) return;
    // Newest first, so the note lands back where it was.
    final notes = [...state.notes, note]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    emit(state.copyWith(notes: notes));
    await restoreNoteUseCase(note);
  }

  @override
  Future<void> close() {
    // CRITICAL: always cancel the subscription to prevent memory leaks.
    _workspaceSubscription.cancel();
    return super.close();
  }
}
