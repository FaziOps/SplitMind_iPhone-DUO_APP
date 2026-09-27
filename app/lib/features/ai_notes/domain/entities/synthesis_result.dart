import 'ai_note.dart';
import 'quota_status.dart';

class SynthesisResult {
  const SynthesisResult({required this.note, this.quota});

  final AiNote note;
  final QuotaStatus? quota;
}
