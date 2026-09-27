import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../workspace/domain/entities/highlight.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../../workspace/presentation/bloc/active_workspace_bloc.dart';
import '../../domain/entities/reader_document.dart';
import '../../domain/repos/document_repository.dart';

/// What the reader should do when the workspace first opens (from onboarding).
enum ReaderLaunchAction { none, importPdf, openSample }

// --- EVENTS ---
sealed class ReaderEvent {
  const ReaderEvent();
}

class ReaderStarted extends ReaderEvent {
  const ReaderStarted({this.launchAction = ReaderLaunchAction.none});

  final ReaderLaunchAction launchAction;
}

class ReaderImportRequested extends ReaderEvent {
  const ReaderImportRequested();
}

class ReaderSampleRequested extends ReaderEvent {
  const ReaderSampleRequested();
}

class ReaderPageChanged extends ReaderEvent {
  const ReaderPageChanged(this.page, {this.pageCount});

  final int page;
  final int? pageCount;
}

/// Text selection in the PDF changed; null when cleared.
class ReaderSelectionChanged extends ReaderEvent {
  const ReaderSelectionChanged(this.highlight);

  final Highlight? highlight;
}

/// Send a passage to the notes pane, optionally running [action] right away.
/// Covers the selection menu (FR-3a), the selection bar and "send page".
class ReaderSendToAi extends ReaderEvent {
  const ReaderSendToAi(this.highlight, {this.action});

  final Highlight highlight;
  final SynthesisAction? action;
}

// --- STATE ---
enum ReaderStatus { initial, loading, empty, ready, failure }

class ReaderState extends Equatable {
  const ReaderState({
    this.status = ReaderStatus.initial,
    this.document,
    this.currentPage = 1,
    this.selection,
    this.message,
    this.messageId = 0,
  });

  final ReaderStatus status;
  final ReaderDocument? document;
  final int currentPage;
  final Highlight? selection;

  /// One-shot message for a SnackBar; [messageId] changes each time.
  final String? message;
  final int messageId;

  ReaderState copyWith({
    ReaderStatus? status,
    ReaderDocument? Function()? document,
    int? currentPage,
    Highlight? Function()? selection,
    String? message,
  }) {
    return ReaderState(
      status: status ?? this.status,
      document: document != null ? document() : this.document,
      currentPage: currentPage ?? this.currentPage,
      selection: selection != null ? selection() : this.selection,
      message: message ?? this.message,
      messageId: message != null ? messageId + 1 : messageId,
    );
  }

  @override
  List<Object?> get props => [status, document, currentPage, selection, message, messageId];
}

// --- BLOC ---
class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  ReaderBloc({required this.activeWorkspaceBloc, required this.documentRepository}) : super(const ReaderState()) {
    on<ReaderStarted>(_onStarted);
    on<ReaderImportRequested>((event, emit) => _import(emit, documentRepository.pickAndImport));
    on<ReaderSampleRequested>((event, emit) => _import(emit, documentRepository.importSample));
    on<ReaderPageChanged>(_onPageChanged);
    on<ReaderSelectionChanged>(_onSelectionChanged);
    on<ReaderSendToAi>(_onSendToAi);
  }

  final ActiveWorkspaceBloc activeWorkspaceBloc;
  final DocumentRepository documentRepository;

  Future<void> _onStarted(ReaderStarted event, Emitter<ReaderState> emit) async {
    emit(state.copyWith(status: ReaderStatus.loading));
    switch (event.launchAction) {
      case ReaderLaunchAction.openSample:
        return _import(emit, documentRepository.importSample);
      case ReaderLaunchAction.importPdf:
        return _import(emit, documentRepository.pickAndImport);
      case ReaderLaunchAction.none:
        try {
          final doc = await documentRepository.getActiveDocument();
          emit(_opened(doc));
        } catch (_) {
          emit(state.copyWith(status: ReaderStatus.empty));
        }
    }
  }

  Future<void> _import(Emitter<ReaderState> emit, Future<ReaderDocument?> Function() load) async {
    final previous = state;
    emit(state.copyWith(status: ReaderStatus.loading));
    try {
      final doc = await load();
      if (doc == null) {
        // Cancelled: fall back to whatever was showing before.
        emit(previous.document == null ? previous.copyWith(status: ReaderStatus.empty) : previous);
        return;
      }
      activeWorkspaceBloc.add(const HighlightCleared());
      emit(_opened(doc));
    } on DocumentImportException catch (e) {
      emit(
        previous.copyWith(
          status: previous.document == null ? ReaderStatus.failure : ReaderStatus.ready,
          message: e.message,
        ),
      );
    } catch (_) {
      emit(
        previous.copyWith(
          status: previous.document == null ? ReaderStatus.failure : ReaderStatus.ready,
          message: "Couldn't open that document.",
        ),
      );
    }
  }

  ReaderState _opened(ReaderDocument? doc) {
    if (doc == null) {
      return state.copyWith(status: ReaderStatus.empty, document: () => null, selection: () => null);
    }
    return state.copyWith(
      status: ReaderStatus.ready,
      document: () => doc,
      currentPage: doc.lastPage,
      selection: () => null,
    );
  }

  Future<void> _onPageChanged(ReaderPageChanged event, Emitter<ReaderState> emit) async {
    final doc = state.document;
    if (doc == null) return;
    final pageCount = event.pageCount ?? doc.pageCount;
    if (event.page == state.currentPage && pageCount == doc.pageCount) return;
    emit(
      state.copyWith(
        currentPage: event.page,
        document: () => doc.copyWith(lastPage: event.page, pageCount: pageCount),
      ),
    );
    await documentRepository.saveReadingPosition(doc.id, page: event.page, pageCount: pageCount);
  }

  void _onSelectionChanged(ReaderSelectionChanged event, Emitter<ReaderState> emit) {
    final highlight = event.highlight;
    if (highlight == state.selection) return;
    emit(state.copyWith(selection: () => highlight));
    activeWorkspaceBloc.add(highlight == null ? const HighlightCleared() : TextHighlighted(highlight));
  }

  void _onSendToAi(ReaderSendToAi event, Emitter<ReaderState> emit) {
    final action = event.action;
    activeWorkspaceBloc.add(
      action == null ? HighlightSentToAi(event.highlight) : SynthesisRequested(action, event.highlight),
    );
  }
}
