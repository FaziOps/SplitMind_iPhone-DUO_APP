import 'package:flutter_test/flutter_test.dart';
import 'package:splitmind/core/utils/passage_text.dart';
import 'package:splitmind/features/ai_notes/presentation/widgets/flashcard_deck.dart';

void main() {
  group('parseFlashcards', () {
    test('reads cards separated by --- lines, including multi-line answers', () {
      const markdown =
          '**Q:** What does the cornea do?\n**A:** Focuses light.\nIt gives two thirds of the power.\n\n---\n\n'
          '**Q:** What is the fovea?\n**A:** The sharpest part of the retina.';
      final cards = parseFlashcards(markdown)!;
      expect(cards, hasLength(2));
      expect(cards[0].question, 'What does the cornea do?');
      expect(cards[0].answer, 'Focuses light.\nIt gives two thirds of the power.');
      expect(cards[1].question, 'What is the fovea?');
    });

    test('returns null for Markdown that does not follow the contract', () {
      expect(parseFlashcards('### Summary\n- not cards'), isNull);
      expect(parseFlashcards('**Q:** A question with no answer'), isNull);
      expect(parseFlashcards(''), isNull);
    });
  });

  test('normalizePassage joins PDF line breaks into flowing text', () {
    expect(
      normalizePassage('  The human eye is a roughly\nspherical organ.  It\n\nworks like a camera. '),
      'The human eye is a roughly spherical organ. It works like a camera.',
    );
  });
}
