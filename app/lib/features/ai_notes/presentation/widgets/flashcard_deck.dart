import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// One question and answer from a flashcard note.
typedef Flashcard = ({String question, String answer});

final _cardPattern = RegExp(r'^\*\*Q:\*\*\s*(.+?)\s*\*\*A:\*\*\s*(.+)$', dotAll: true);
final _separator = RegExp(r'^\s*---\s*$', multiLine: true);

/// Parses the flashcard Markdown contract from the backend (DR-2): cards of
/// `**Q:** …` / `**A:** …`, separated by `---` lines. Returns null when the
/// text doesn't follow it, so the caller can fall back to plain Markdown.
List<Flashcard>? parseFlashcards(String markdown) {
  final cards = <Flashcard>[];
  for (final chunk in markdown.split(_separator)) {
    final trimmed = chunk.trim();
    if (trimmed.isEmpty) continue;
    final match = _cardPattern.firstMatch(trimmed);
    if (match == null) return null;
    cards.add((question: match.group(1)!.trim(), answer: match.group(2)!.trim()));
  }
  return cards.isEmpty ? null : cards;
}

/// Study view for flashcard notes: answers stay hidden until tapped, so the
/// reader practises recall instead of rereading.
class FlashcardDeck extends StatefulWidget {
  const FlashcardDeck({super.key, required this.cards});

  final List<Flashcard> cards;

  @override
  State<FlashcardDeck> createState() => _FlashcardDeckState();
}

class _FlashcardDeckState extends State<FlashcardDeck> {
  final _revealed = <int>{};

  bool get _allRevealed => _revealed.length == widget.cards.length;

  void _toggleAll() => setState(() {
    if (_allRevealed) {
      _revealed.clear();
    } else {
      _revealed.addAll(List.generate(widget.cards.length, (i) => i));
    }
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, card) in widget.cards.indexed) ...[
          _CardTile(
            index: i,
            card: card,
            revealed: _revealed.contains(i),
            onTap: () => setState(() => _revealed.contains(i) ? _revealed.remove(i) : _revealed.add(i)),
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _toggleAll,
            icon: Icon(_allRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
            label: Text(_allRevealed ? 'Hide answers' : 'Show all answers'),
            style: TextButton.styleFrom(foregroundColor: scheme.primary),
          ),
        ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.index, required this.card, required this.revealed, required this.onTap});

  final int index;
  final Flashcard card;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: 'Card ${index + 1}. ${card.question}',
      hint: revealed ? 'Answer: ${card.answer}' : 'Double tap to reveal the answer',
      excludeSemantics: true,
      child: Material(
        color: revealed ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Card ${index + 1}', style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary)),
                const SizedBox(height: 4),
                MarkdownBody(data: card.question),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: revealed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_outlined, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to reveal the answer',
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        MarkdownBody(data: card.answer),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
