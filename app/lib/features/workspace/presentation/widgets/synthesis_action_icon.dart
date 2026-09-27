import 'package:flutter/material.dart';

import '../../domain/entities/synthesis_action.dart';

extension SynthesisActionIcon on SynthesisAction {
  IconData get icon => switch (this) {
    SynthesisAction.explain => Icons.lightbulb_outline,
    SynthesisAction.summarize => Icons.short_text,
    SynthesisAction.flashcard => Icons.style_outlined,
    SynthesisAction.simplify => Icons.child_care_outlined,
    SynthesisAction.terms => Icons.menu_book_outlined,
    SynthesisAction.quiz => Icons.quiz_outlined,
    SynthesisAction.ask => Icons.question_answer_outlined,
  };
}
