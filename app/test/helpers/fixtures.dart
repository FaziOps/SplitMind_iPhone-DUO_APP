import 'package:splitmind/features/ai_notes/domain/entities/ai_note.dart';
import 'package:splitmind/features/workspace/domain/entities/highlight.dart';
import 'package:splitmind/features/workspace/domain/entities/synthesis_action.dart';

const highlightA = Highlight(
  text: 'Spaced repetition beats cramming.',
  docId: 'doc-1',
  docTitle: 'Memory',
  pageNumber: 2,
);
const highlightB = Highlight(
  text: 'Active recall strengthens memory.',
  docId: 'doc-1',
  docTitle: 'Memory',
  pageNumber: 3,
);

AiNote noteFor(Highlight h, SynthesisAction action, {String id = 'note-1', DateTime? at}) => AiNote(
  id: id,
  action: action,
  markdown: '### Summary\n- ${h.text}',
  sourceText: h.text,
  sourceDocId: h.docId,
  sourceDocTitle: h.docTitle,
  sourcePage: h.pageNumber,
  createdAt: at ?? DateTime.utc(2026, 9, 1),
);
