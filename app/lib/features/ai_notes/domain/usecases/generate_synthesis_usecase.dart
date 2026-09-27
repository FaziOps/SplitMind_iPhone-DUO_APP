import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/ai_exceptions.dart';
import '../../../workspace/domain/entities/highlight.dart';
import '../../../workspace/domain/entities/synthesis_action.dart';
import '../entities/synthesis_result.dart';
import '../repos/notes_repository.dart';

class GenerateSynthesisUseCase {
  const GenerateSynthesisUseCase(this.repository);

  final NotesRepository repository;

  Future<SynthesisResult> call(Highlight highlight, SynthesisAction action, {String? question}) {
    final text = highlight.text.trim();
    if (text.isEmpty) {
      throw const InvalidRequestException('Highlighted text cannot be empty.');
    }
    if (text.length > AiConstants.maxPassageChars) {
      throw const InvalidRequestException(
        'That selection is too long. Select at most ${AiConstants.maxPassageChars} characters.',
      );
    }
    final asked = question?.trim();
    if (action.requiresQuestion) {
      if (asked == null || asked.isEmpty) {
        throw const InvalidRequestException('Type a question about the passage first.');
      }
      if (asked.length > AiConstants.maxQuestionChars) {
        throw const InvalidRequestException(
          'That question is too long. Ask in at most ${AiConstants.maxQuestionChars} characters.',
        );
      }
    }
    return repository.synthesize(
      Highlight(text: text, docId: highlight.docId, docTitle: highlight.docTitle, pageNumber: highlight.pageNumber),
      action,
      question: action.requiresQuestion ? asked : null,
    );
  }
}
