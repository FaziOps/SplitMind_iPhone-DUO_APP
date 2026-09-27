import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/highlight.dart';
import '../../domain/entities/synthesis_action.dart';

// Mediator (PRD Section 3): the only object both panes know about. The reader
// reports selections and requests here; the notes pane observes this state.
// Neither pane imports the other.

// --- EVENTS ---
sealed class ActiveWorkspaceEvent extends Equatable {
  const ActiveWorkspaceEvent();

  @override
  List<Object?> get props => [];
}

/// The live selection in the reader changed. Costs nothing: highlighting never
/// calls the AI by itself (NFR-5).
class TextHighlighted extends ActiveWorkspaceEvent {
  const TextHighlighted(this.highlight);

  final Highlight highlight;

  @override
  List<Object?> get props => [highlight];
}

class HighlightCleared extends ActiveWorkspaceEvent {
  const HighlightCleared();
}

/// "Send to AI" (FR-3a) or a drop onto the notes pane (FR-3): the passage
/// becomes the notes pane's context, waiting for the user to pick an action.
class HighlightSentToAi extends ActiveWorkspaceEvent {
  const HighlightSentToAi(this.highlight);

  final Highlight highlight;

  @override
  List<Object?> get props => [highlight];
}

/// Explain / Summarize / Flashcard chosen from the reader's selection menu.
class SynthesisRequested extends ActiveWorkspaceEvent {
  const SynthesisRequested(this.action, this.highlight);

  final SynthesisAction action;
  final Highlight highlight;

  @override
  List<Object?> get props => [action, highlight];
}

/// The notes pane dismissed its context card.
class AiContextCleared extends ActiveWorkspaceEvent {
  const AiContextCleared();
}

/// A note's citation was tapped: the reader should show that page (FR-8).
class SourcePageRequested extends ActiveWorkspaceEvent {
  const SourcePageRequested({required this.docId, required this.page});

  final String? docId;
  final int page;

  @override
  List<Object?> get props => [docId, page];
}

/// Where the reader was asked to go. [id] increases with every request, so
/// asking for the same page twice still moves the reader.
class PageRequest extends Equatable {
  const PageRequest({required this.id, required this.docId, required this.page});

  final int id;
  final String? docId;
  final int page;

  @override
  List<Object?> get props => [id, docId, page];
}

// --- STATE ---
class ActiveWorkspaceState extends Equatable {
  const ActiveWorkspaceState({this.activeHighlight, this.aiContext, this.lastCommand, this.pageRequest});

  /// What is selected in the reader right now.
  final Highlight? activeHighlight;

  /// The passage the notes pane is working with.
  final Highlight? aiContext;

  /// The most recent AI request; its id increases with every request.
  final SynthesisCommand? lastCommand;

  /// The most recent "show this page" request from the notes pane.
  final PageRequest? pageRequest;

  // The v1 copyWith used `value ?? this.value`, which can never clear a field.
  // Nullable fields take a getter so callers can pass `() => null`.
  ActiveWorkspaceState copyWith({
    Highlight? Function()? activeHighlight,
    Highlight? Function()? aiContext,
    SynthesisCommand? lastCommand,
    PageRequest? pageRequest,
  }) {
    return ActiveWorkspaceState(
      activeHighlight: activeHighlight != null ? activeHighlight() : this.activeHighlight,
      aiContext: aiContext != null ? aiContext() : this.aiContext,
      lastCommand: lastCommand ?? this.lastCommand,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }

  @override
  List<Object?> get props => [activeHighlight, aiContext, lastCommand, pageRequest];
}

// --- BLOC ---
class ActiveWorkspaceBloc extends Bloc<ActiveWorkspaceEvent, ActiveWorkspaceState> {
  ActiveWorkspaceBloc() : super(const ActiveWorkspaceState()) {
    on<TextHighlighted>((event, emit) {
      emit(state.copyWith(activeHighlight: () => event.highlight));
    });
    on<HighlightCleared>((event, emit) {
      emit(state.copyWith(activeHighlight: () => null));
    });
    on<HighlightSentToAi>((event, emit) {
      emit(state.copyWith(aiContext: () => event.highlight));
    });
    on<SynthesisRequested>((event, emit) {
      emit(
        state.copyWith(
          aiContext: () => event.highlight,
          lastCommand: SynthesisCommand(
            id: (state.lastCommand?.id ?? 0) + 1,
            action: event.action,
            highlight: event.highlight,
          ),
        ),
      );
    });
    on<AiContextCleared>((event, emit) {
      emit(state.copyWith(aiContext: () => null));
    });
    on<SourcePageRequested>((event, emit) {
      emit(
        state.copyWith(
          pageRequest: PageRequest(id: (state.pageRequest?.id ?? 0) + 1, docId: event.docId, page: event.page),
        ),
      );
    });
  }
}
