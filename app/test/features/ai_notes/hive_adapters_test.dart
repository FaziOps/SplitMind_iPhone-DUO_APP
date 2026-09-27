import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:splitmind/features/ai_notes/data/models/note_model.dart';
import 'package:splitmind/features/ai_notes/domain/entities/ai_note.dart';
import 'package:splitmind/features/reader/data/models/document_model.dart';
import 'package:splitmind/features/workspace/domain/entities/synthesis_action.dart';

import '../../helpers/fixtures.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('splitmind_hive_test');
    Hive
      ..init(dir.path)
      ..registerAdapter(NoteModelAdapter())
      ..registerAdapter(DocumentModelAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('NoteModel survives a close and reopen (FR-6)', () async {
    final note = noteFor(highlightA, SynthesisAction.flashcard, id: 'n1');
    var box = await Hive.openBox<NoteModel>('notes');
    await box.put(note.id, NoteModel.fromEntity(note));
    await box.close();

    box = await Hive.openBox<NoteModel>('notes');
    expect(box.get('n1')!.toEntity(), note);
  });

  test('NoteModel keeps the question of an ask note', () async {
    final base = noteFor(highlightA, SynthesisAction.ask, id: 'n2');
    final note = AiNote(
      id: base.id,
      action: base.action,
      markdown: base.markdown,
      sourceText: base.sourceText,
      sourceDocId: base.sourceDocId,
      sourceDocTitle: base.sourceDocTitle,
      sourcePage: base.sourcePage,
      createdAt: base.createdAt,
      question: 'Why does it work?',
    );
    var box = await Hive.openBox<NoteModel>('notes');
    await box.put(note.id, NoteModel.fromEntity(note));
    await box.close();

    box = await Hive.openBox<NoteModel>('notes');
    expect(box.get('n2')!.toEntity(), note);
  });

  test('DocumentModel round-trips nullable fields', () async {
    final box = await Hive.openBox<DocumentModel>('documents');
    final model = DocumentModel(
      id: 'd1',
      title: 'Paper',
      fileName: 'd1.pdf',
      lastPage: 7,
      importedAt: DateTime.utc(2026, 9, 1),
    );
    await box.put('d1', model);
    await box.close();

    final reopened = (await Hive.openBox<DocumentModel>('documents')).get('d1')!;
    expect(reopened.lastPage, 7);
    expect(reopened.pageCount, isNull);
    expect(reopened.fileName, 'd1.pdf');
  });
}
