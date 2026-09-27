import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/ai_exceptions.dart';
import '../../../../core/utils/passage_text.dart';
import '../../../workspace/domain/entities/highlight.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../../workspace/presentation/bloc/active_workspace_bloc.dart';
import '../../domain/entities/reader_document.dart';
import '../bloc/reader_bloc.dart';
import 'reader_empty_state.dart';
import 'reader_toolbar.dart';
import 'selection_action_bar.dart';

/// The left pane: source material (FR-5, PDF only in Phase 1).
class DocumentViewer extends StatelessWidget {
  const DocumentViewer({super.key, this.toolbarTrailing});

  /// Extra toolbar content supplied by the workspace (e.g. debug tools).
  final Widget? toolbarTrailing;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReaderBloc, ReaderState>(
      listenWhen: (a, b) => a.messageId != b.messageId && b.message != null,
      listener: (context, state) => _showMessage(context, state.message!),
      buildWhen: (a, b) => a.status != b.status || a.document?.id != b.document?.id,
      builder: (context, state) {
        final doc = state.document;
        return switch (state.status) {
          ReaderStatus.initial || ReaderStatus.loading when doc == null => const _Loading(),
          ReaderStatus.empty => const ReaderEmptyState(),
          ReaderStatus.failure when doc == null => ReaderEmptyState(errorMessage: state.message),
          _ when doc != null => _DocumentPane(key: ValueKey(doc.id), document: doc, toolbarTrailing: toolbarTrailing),
          _ => const _Loading(),
        };
      },
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading document'));
  }
}

class _DocumentPane extends StatefulWidget {
  const _DocumentPane({super.key, required this.document, this.toolbarTrailing});

  final ReaderDocument document;
  final Widget? toolbarTrailing;

  @override
  State<_DocumentPane> createState() => _DocumentPaneState();
}

class _DocumentPaneState extends State<_DocumentPane> {
  final _controller = PdfViewerController();
  int _selectionSeq = 0;
  bool _warnedRestricted = false;

  ReaderBloc get _bloc => context.read<ReaderBloc>();
  ReaderDocument get _doc => widget.document;

  bool get _copyAllowed {
    if (!_controller.isReady) return true;
    return _controller.document.permissions?.allowsCopying ?? true;
  }

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    _bloc.add(ReaderPageChanged(controller.pageNumber ?? _doc.lastPage, pageCount: document.pages.length));
  }

  void _onPageChanged(int? page) {
    if (page != null) _bloc.add(ReaderPageChanged(page));
  }

  Future<void> _onTextSelectionChange(PdfTextSelection selection) async {
    final seq = ++_selectionSeq;
    if (!selection.hasSelectedText) {
      _bloc.add(const ReaderSelectionChanged(null));
      return;
    }
    // DR-3: honor the PDF's own "no copying" permission.
    if (!selection.isCopyAllowed) {
      if (!_warnedRestricted) {
        _warnedRestricted = true;
        _showMessage(context, const ContentRestrictedException().message);
      }
      return;
    }
    final highlight = await _readSelection(selection);
    // Selection handles fire many events; drop results that were overtaken.
    if (!mounted || seq != _selectionSeq) return;
    _bloc.add(ReaderSelectionChanged(highlight));
  }

  Future<Highlight?> _readSelection(PdfTextSelection selection) async {
    final text = normalizePassage(await selection.getSelectedText());
    if (text.isEmpty) return null;
    final ranges = await selection.getSelectedTextRanges();
    return Highlight(
      text: text,
      docId: _doc.id,
      docTitle: _doc.title,
      pageNumber: ranges.isEmpty ? _bloc.state.currentPage : ranges.first.pageNumber,
    );
  }

  /// FR-3a: the core AI actions live in the system text-selection menu, so
  /// they work without drag and drop (VoiceOver, one hand, standard iPhone).
  void _customizeContextMenu(PdfViewerContextMenuBuilderParams params, List<ContextMenuButtonItem> items) {
    final delegate = params.textSelectionDelegate;
    if (!params.isTextSelectionEnabled || !delegate.hasSelectedText || !delegate.isCopyAllowed) return;

    Future<void> send(SynthesisAction? action) async {
      params.dismissContextMenu();
      final highlight = _bloc.state.selection ?? await _readSelection(delegate);
      if (highlight == null || !mounted) return;
      _bloc.add(ReaderSendToAi(highlight, action: action));
    }

    final insertAt = items.isEmpty ? 0 : 1; // keep "Copy" first
    items.insertAll(insertAt, [
      ContextMenuButtonItem(label: 'Send to AI', onPressed: () => send(null)),
      for (final action in SynthesisAction.menuActions)
        ContextMenuButtonItem(label: action.label, onPressed: () => send(action)),
    ]);
  }

  /// Sends the whole current page: a selection-free path for VoiceOver users.
  Future<void> _sendCurrentPage() async {
    if (!_controller.isReady) return;
    if (!_copyAllowed) {
      _showMessage(context, const ContentRestrictedException().message);
      return;
    }
    final pageNumber = _bloc.state.currentPage.clamp(1, _controller.pages.length);
    final raw = await _controller.pages[pageNumber - 1].loadText();
    if (!mounted) return;
    var text = normalizePassage(raw?.fullText ?? '');
    if (text.isEmpty) {
      _showMessage(context, 'This page has no selectable text. It may be a scanned image.');
      return;
    }
    if (text.length > AiConstants.maxPassageChars) {
      text = text.substring(0, AiConstants.maxPassageChars);
      _showMessage(context, 'Only the first ${AiConstants.maxPassageChars} characters of this page were sent.');
    }
    _bloc.add(ReaderSendToAi(Highlight(text: text, docId: _doc.id, docTitle: _doc.title, pageNumber: pageNumber)));
  }

  /// Shows [page] of this document, e.g. from a note's citation or the
  /// toolbar's "Go to page".
  Future<void> _goToPage(int page) async {
    if (!_controller.isReady) return;
    await _controller.goToPage(pageNumber: page.clamp(1, _controller.pages.length), anchor: PdfPageAnchor.top);
  }

  void _onPageRequest(BuildContext context, ActiveWorkspaceState state) {
    final request = state.pageRequest!;
    if (request.docId != null && request.docId != _doc.id) {
      _showMessage(context, 'That note comes from another document. Open it to see the source.');
      return;
    }
    _goToPage(request.page);
  }

  Future<void> _clearSelection() async {
    await _controller.textSelectionDelegate.clearTextSelection();
    _bloc.add(const ReaderSelectionChanged(null));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocListener<ActiveWorkspaceBloc, ActiveWorkspaceState>(
      listenWhen: (a, b) => b.pageRequest != null && a.pageRequest != b.pageRequest,
      listener: _onPageRequest,
      child: Column(
        children: [
          ReaderToolbar(onSendPage: _sendCurrentPage, onGoToPage: _goToPage, trailing: widget.toolbarTrailing),
          const Divider(),
          Expanded(
            child: PdfViewer.file(
              _doc.filePath,
              controller: _controller,
              initialPageNumber: _doc.lastPage,
              params: PdfViewerParams(
                // Keeps pages at fit-width when the pane resizes (fold, unfold,
                // laptop mode) instead of keeping the old zoom and clipping.
                sizeDelegateProvider: const PdfViewerSizeDelegateProviderSmart(),
                backgroundColor: scheme.surfaceContainerHighest,
                onViewerReady: _onViewerReady,
                onPageChanged: _onPageChanged,
                textSelectionParams: PdfTextSelectionParams(onTextSelectionChange: _onTextSelectionChange),
                customizeContextMenuItems: _customizeContextMenu,
                errorBannerBuilder: _buildError,
              ),
            ),
          ),
          BlocBuilder<ReaderBloc, ReaderState>(
            buildWhen: (a, b) => a.selection != b.selection,
            builder: (context, state) {
              final selection = state.selection;
              return AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: selection == null
                    ? const SizedBox(width: double.infinity)
                    : SelectionActionBar(
                        highlight: selection,
                        onAction: (action) => _bloc.add(ReaderSendToAi(selection, action: action)),
                        onClear: _clearSelection,
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error, StackTrace? stackTrace, PdfDocumentRef ref) {
    return ReaderEmptyState(errorMessage: "This PDF couldn't be opened. It may be damaged or password-protected.");
  }
}
