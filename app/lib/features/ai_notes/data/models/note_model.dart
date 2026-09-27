import 'package:hive_ce/hive.dart';

import '../../../workspace/domain/entities/synthesis_action.dart';
import '../../domain/entities/ai_note.dart';

/// Hive schema for cached notes (FR-6).
///
/// | field | type     | meaning                              |
/// |-------|----------|--------------------------------------|
/// | 0     | String   | id                                   |
/// | 1     | String   | action (SynthesisAction.name)        |
/// | 2     | String   | markdown                             |
/// | 3     | String   | sourceText                           |
/// | 4     | String?  | sourceDocId                          |
/// | 5     | String?  | sourceDocTitle                       |
/// | 6     | int?     | sourcePage                           |
/// | 7     | DateTime | createdAt                            |
/// | 8     | String?  | question (absent before v1.1)        |
///
/// Field numbers are permanent: add new fields with new numbers, never reuse
/// or renumber, so existing caches keep loading.
class NoteModel {
  const NoteModel({
    required this.id,
    required this.action,
    required this.markdown,
    required this.sourceText,
    required this.createdAt,
    this.sourceDocId,
    this.sourceDocTitle,
    this.sourcePage,
    this.question,
  });

  factory NoteModel.fromEntity(AiNote note) => NoteModel(
    id: note.id,
    action: note.action.name,
    markdown: note.markdown,
    sourceText: note.sourceText,
    sourceDocId: note.sourceDocId,
    sourceDocTitle: note.sourceDocTitle,
    sourcePage: note.sourcePage,
    createdAt: note.createdAt,
    question: note.question,
  );

  static const int typeId = 0;

  final String id;
  final String action;
  final String markdown;
  final String sourceText;
  final String? sourceDocId;
  final String? sourceDocTitle;
  final int? sourcePage;
  final DateTime createdAt;
  final String? question;

  AiNote toEntity() => AiNote(
    id: id,
    action: SynthesisAction.tryParse(action) ?? SynthesisAction.summarize,
    markdown: markdown,
    sourceText: sourceText,
    sourceDocId: sourceDocId,
    sourceDocTitle: sourceDocTitle,
    sourcePage: sourcePage,
    createdAt: createdAt,
    question: question,
  );
}

/// Hand-written adapter in the same binary format hive_ce_generator emits,
/// so the project needs no build_runner step.
class NoteModelAdapter extends TypeAdapter<NoteModel> {
  @override
  final int typeId = NoteModel.typeId;

  @override
  NoteModel read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{for (var i = 0; i < count; i++) reader.readByte(): reader.read()};
    return NoteModel(
      id: fields[0] as String,
      action: fields[1] as String,
      markdown: fields[2] as String,
      sourceText: fields[3] as String,
      sourceDocId: fields[4] as String?,
      sourceDocTitle: fields[5] as String?,
      sourcePage: fields[6] as int?,
      createdAt: fields[7] as DateTime,
      question: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NoteModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.action)
      ..writeByte(2)
      ..write(obj.markdown)
      ..writeByte(3)
      ..write(obj.sourceText)
      ..writeByte(4)
      ..write(obj.sourceDocId)
      ..writeByte(5)
      ..write(obj.sourceDocTitle)
      ..writeByte(6)
      ..write(obj.sourcePage)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.question);
  }
}
