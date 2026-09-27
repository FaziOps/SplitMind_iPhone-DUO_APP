import 'dart:io';
import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

import '../../../../core/storage/app_settings.dart';
import '../models/document_model.dart';

/// Stores PDF files under the app's support directory and their metadata in
/// Hive.
class DocumentLocalDataSource {
  DocumentLocalDataSource({required this._box, required this._settings, required this._storageRoot});

  final Box<DocumentModel> _box;
  final AppSettings _settings;
  final Future<Directory> Function() _storageRoot;

  Future<Directory> _documentsDir() async {
    final dir = Directory('${(await _storageRoot()).path}/documents');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> resolvePath(String fileName) async => '${(await _documentsDir()).path}/$fileName';

  Future<String> copyIn(String sourcePath, String fileName) async {
    final target = await resolvePath(fileName);
    await File(sourcePath).copy(target);
    return target;
  }

  Future<String> writeBytes(Uint8List bytes, String fileName) async {
    final target = await resolvePath(fileName);
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }

  Future<void> save(DocumentModel model) async {
    await _box.put(model.id, model);
    await _box.flush();
  }

  DocumentModel? get(String id) => _box.get(id);

  String? get activeDocumentId => _settings.activeDocumentId;

  Future<void> setActive(String id) => _settings.setActiveDocumentId(id);
}
