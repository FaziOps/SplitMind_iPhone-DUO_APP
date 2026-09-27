import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'core/storage/app_settings.dart';
import 'features/ai_notes/data/models/note_model.dart';
import 'features/reader/data/models/document_model.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();

  // Open Hive boxes before the first frame so cached notes and the last
  // document are ready immediately (FR-6).
  await Hive.initFlutter();
  Hive
    ..registerAdapter(NoteModelAdapter())
    ..registerAdapter(DocumentModelAdapter());
  final (notesBox, documentsBox, settingsBox) = await (
    Hive.openBox<NoteModel>('notes'),
    Hive.openBox<DocumentModel>('documents'),
    Hive.openBox<dynamic>(AppSettings.boxName),
  ).wait;

  await initDependencies(notesBox: notesBox, documentsBox: documentsBox, settingsBox: settingsBox);
  runApp(const SplitMindApp());
}
