import '../entities/reader_document.dart';

abstract class DocumentRepository {
  /// Lets the user pick a PDF and copies it into app storage so it survives
  /// the original file moving (FR-6). Returns null if the user cancels.
  Future<ReaderDocument?> pickAndImport();

  /// Imports the bundled sample so a first document is one tap away (FR-10).
  Future<ReaderDocument> importSample();

  /// The document that was open last, or null if none or its file is gone.
  Future<ReaderDocument?> getActiveDocument();

  Future<void> saveReadingPosition(String documentId, {required int page, int? pageCount});
}

class DocumentImportException implements Exception {
  const DocumentImportException(this.message);

  final String message;

  @override
  String toString() => 'DocumentImportException: $message';
}
