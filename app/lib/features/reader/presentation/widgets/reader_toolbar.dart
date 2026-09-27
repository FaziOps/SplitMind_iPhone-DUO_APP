import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/reader_bloc.dart';

class ReaderToolbar extends StatelessWidget {
  const ReaderToolbar({super.key, required this.onSendPage, required this.onGoToPage, this.trailing});

  final VoidCallback onSendPage;
  final ValueChanged<int> onGoToPage;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<ReaderBloc, ReaderState>(
      buildWhen: (a, b) => a.document != b.document || a.currentPage != b.currentPage,
      builder: (context, state) {
        final doc = state.document;
        final pageCount = doc?.pageCount;
        final pageLabel = pageCount == null ? 'Page ${state.currentPage}' : 'Page ${state.currentPage} of $pageCount';
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        doc?.title ?? '',
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      _PageLabel(
                        label: pageLabel,
                        onTap: pageCount == null || pageCount < 2
                            ? null
                            : () async {
                                final page = await _askForPage(
                                  context,
                                  current: state.currentPage,
                                  pageCount: pageCount,
                                );
                                if (page != null) onGoToPage(page);
                              },
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send this page to AI',
                icon: const Icon(Icons.auto_awesome_outlined),
                onPressed: onSendPage,
              ),
              ?trailing,
              PopupMenuButton<_MenuItem>(
                tooltip: 'Document options',
                onSelected: (item) => switch (item) {
                  _MenuItem.importPdf => context.read<ReaderBloc>().add(const ReaderImportRequested()),
                  _MenuItem.sample => context.read<ReaderBloc>().add(const ReaderSampleRequested()),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: _MenuItem.importPdf, child: Text('Open another PDF')),
                  PopupMenuItem(value: _MenuItem.sample, child: Text('Open sample document')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _MenuItem { importPdf, sample }

/// "Page 3 of 12", which opens "Go to page" when tapped.
class _PageLabel extends StatelessWidget {
  const _PageLabel({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = Text(label, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant));
    if (onTap == null) return text;
    return Semantics(
      button: true,
      label: '$label. Go to page',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            text,
            Icon(Icons.arrow_drop_down, size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

Future<int?> _askForPage(BuildContext context, {required int current, required int pageCount}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _GoToPageDialog(current: current, pageCount: pageCount),
  );
}

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.current, required this.pageCount});

  final int current;
  final int pageCount;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final _field = TextEditingController(text: '${widget.current}')
    ..selection = TextSelection(baseOffset: 0, extentOffset: '${widget.current}'.length);

  int? get _page {
    final page = int.tryParse(_field.text.trim());
    return page != null && page >= 1 && page <= widget.pageCount ? page : null;
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final page = _page;
    if (page != null) Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _field,
      builder: (context, _) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: _field,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            helperText: '1 to ${widget.pageCount}',
            errorText: _field.text.trim().isEmpty || _page != null
                ? null
                : 'Enter a page from 1 to ${widget.pageCount}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: _page == null ? null : _submit, child: const Text('Go')),
        ],
      ),
    );
  }
}
