import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../domain/entities/reader_document.dart';
import '../../domain/repos/document_repository.dart';
import '../models/document_model.dart';
import '../sources/document_local_data_source.dart';
import '../sources/document_picker.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl({
    required this._local,
    required this._picker,
    required this._loadSampleBytes,
    Uuid? uuid,
    DateTime Function()? clock,
  }) : _uuid = uuid ?? const Uuid(),
       _clock = clock ?? DateTime.now;

  static const sampleTitle = 'Welcome to SplitMind';
  static const _sampleId = 'sample-welcome';

  final DocumentLocalDataSource _local;
  final DocumentPicker _picker;
  final Future<Uint8List> Function() _loadSampleBytes;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<ReaderDocument?> pickAndImport() async {
    final picked = await _picker.pickPdf();
    if (picked == null) return null;

    final id = _uuid.v4();
    final fileName = '$id.pdf';
    final String path;
    try {
      path = await _local.copyIn(picked.path, fileName);
    } on FileSystemException catch (e) {
      throw DocumentImportException("Couldn't import that file: ${e.message}");
    }
    final model = DocumentModel(
      id: id,
      title: _titleFrom(picked.name),
      fileName: fileName,
      lastPage: 1,
      importedAt: _clock(),
    );
    await _local.save(model);
    await _local.setActive(id);
    return _toEntity(model, path);
  }

  @override
  Future<ReaderDocument> importSample() async {
    final existing = _local.get(_sampleId);
    if (existing != null) {
      final path = await _local.resolvePath(existing.fileName);
      if (File(path).existsSync()) {
        await _local.setActive(_sampleId);
        return _toEntity(existing, path);
      }
    }
    const fileName = '$_sampleId.pdf';
    final path = await _local.writeBytes(await _loadSampleBytes(), fileName);
    final model = DocumentModel(
      id: _sampleId,
      title: sampleTitle,
      fileName: fileName,
      lastPage: 1,
      importedAt: _clock(),
    );
    await _local.save(model);
    await _local.setActive(_sampleId);
    return _toEntity(model, path);
  }

  @override
  Future<ReaderDocument?> getActiveDocument() async {
    final id = _local.activeDocumentId;
    if (id == null) return null;
    final model = _local.get(id);
    if (model == null) return null;
    final path = await _local.resolvePath(model.fileName);
    if (!File(path).existsSync()) return null;
    return _toEntity(model, path);
  }

  @override
  Future<void> saveReadingPosition(String documentId, {required int page, int? pageCount}) async {
    final model = _local.get(documentId);
    if (model == null) return;
    if (model.lastPage == page && (pageCount == null || model.pageCount == pageCount)) return;
    await _local.save(model.copyWith(lastPage: page, pageCount: pageCount));
  }

  static String _titleFrom(String fileName) {
    final base = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '').trim();
    return base.isEmpty ? 'Untitled document' : base;
  }

  static ReaderDocument _toEntity(DocumentModel model, String path) => ReaderDocument(
    id: model.id,
    title: model.title,
    filePath: path,
    lastPage: model.lastPage,
    pageCount: model.pageCount,
    importedAt: model.importedAt,
  );
}
