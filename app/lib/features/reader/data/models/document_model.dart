import 'package:hive_ce/hive.dart';

/// Hive schema for imported documents (FR-6).
///
/// | field | type     | meaning                                  |
/// |-------|----------|------------------------------------------|
/// | 0     | String   | id                                       |
/// | 1     | String   | title                                    |
/// | 2     | String   | fileName (relative to documents storage) |
/// | 3     | int      | lastPage (1-based)                       |
/// | 4     | int?     | pageCount                                |
/// | 5     | DateTime | importedAt                               |
///
/// Field numbers are permanent: add, never renumber.
class DocumentModel {
  const DocumentModel({
    required this.id,
    required this.title,
    required this.fileName,
    required this.lastPage,
    required this.importedAt,
    this.pageCount,
  });

  static const int typeId = 1;

  final String id;
  final String title;
  final String fileName;
  final int lastPage;
  final int? pageCount;
  final DateTime importedAt;

  DocumentModel copyWith({int? lastPage, int? pageCount}) => DocumentModel(
    id: id,
    title: title,
    fileName: fileName,
    lastPage: lastPage ?? this.lastPage,
    pageCount: pageCount ?? this.pageCount,
    importedAt: importedAt,
  );
}

class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = DocumentModel.typeId;

  @override
  DocumentModel read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{for (var i = 0; i < count; i++) reader.readByte(): reader.read()};
    return DocumentModel(
      id: fields[0] as String,
      title: fields[1] as String,
      fileName: fields[2] as String,
      lastPage: fields[3] as int,
      pageCount: fields[4] as int?,
      importedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.fileName)
      ..writeByte(3)
      ..write(obj.lastPage)
      ..writeByte(4)
      ..write(obj.pageCount)
      ..writeByte(5)
      ..write(obj.importedAt);
  }
}
