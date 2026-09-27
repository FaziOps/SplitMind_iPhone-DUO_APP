import 'package:flutter/material.dart';

import '../../../reader/presentation/bloc/reader_bloc.dart';
import '../widgets/dual_pane_demo.dart';

/// First-run flow (FR-10): a short interactive demo of the dual-pane idea, the
/// AI data disclosure (NFR-7), then the first import. No permission prompts:
/// the iOS document picker needs none.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final ValueChanged<ReaderLaunchAction> onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;
  static const _pageCount = 3;

  void _next() => _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _Page(
                    title: 'Read on one side.\nThink on the other.',
                    body:
                        'Unfold your iPhone Duo and your document and notes sit side by side. '
                        'On a standard iPhone, notes slide up over the page. Try it:',
                    child: const DualPaneDemo(),
                  ),
                  const _Page(title: 'What gets sent to AI', body: null, child: _PrivacyDisclosure()),
                  _Page(
                    title: 'Open your first document',
                    body: 'Import a PDF from Files, or start with a short sample.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () => widget.onFinished(ReaderLaunchAction.importPdf),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Import a PDF'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => widget.onFinished(ReaderLaunchAction.openSample),
                          child: const Text('Try the sample document'),
                        ),
                        TextButton(
                          onPressed: () => widget.onFinished(ReaderLaunchAction.none),
                          child: const Text('Skip for now'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Semantics(
                    label: 'Step ${_index + 1} of $_pageCount',
                    excludeSemantics: true,
                    child: Row(
                      children: [
                        for (var i = 0; i < _pageCount; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _index ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _index ? scheme.primary : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_index < _pageCount - 1)
                    FilledButton(onPressed: _next, child: Text(_index == 1 ? 'I understand' : 'Next')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.body, required this.child});

  final String title;
  final String? body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall)),
              if (body != null) ...[
                const SizedBox(height: 12),
                Text(body!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// NFR-7 in-app disclosure. Keep this copy accurate to the backend's actual
/// configuration and to the published privacy policy.
class _PrivacyDisclosure extends StatelessWidget {
  const _PrivacyDisclosure();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.touch_app_outlined,
        'Only what you choose',
        'Highlighting alone sends nothing. Text leaves your device only when you tap Explain, Summarize, Flashcards or Send to AI.',
      ),
      (
        Icons.cloud_outlined,
        'Processed by a third-party AI provider',
        "SplitMind's server forwards that text to our AI provider to generate your note.",
      ),
      (
        Icons.block_outlined,
        'Not used for training',
        "We use the provider's API tier that does not train on your content, and our server doesn't store it.",
      ),
      (Icons.smartphone_outlined, 'Notes stay on this device', 'Documents and notes are saved locally on your iPhone.'),
    ];
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (icon, title, body) in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: theme.colorScheme.primary),
            title: Text(title),
            subtitle: Text(body),
          ),
      ],
    );
  }
}
