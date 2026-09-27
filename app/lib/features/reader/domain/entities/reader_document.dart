import 'package:equatable/equatable.dart';

class ReaderDocument extends Equatable {
  const ReaderDocument({
    required this.id,
    required this.title,
    required this.filePath,
    required this.lastPage,
    required this.importedAt,
    this.pageCount,
  });

  final String id;
  final String title;

  /// Absolute path, resolved at load time (the iOS container path can change
  /// between app updates, so only the file name is persisted).
  final String filePath;
  final int lastPage;
  final int? pageCount;
  final DateTime importedAt;

  ReaderDocument copyWith({int? lastPage, int? pageCount}) => ReaderDocument(
    id: id,
    title: title,
    filePath: filePath,
    lastPage: lastPage ?? this.lastPage,
    pageCount: pageCount ?? this.pageCount,
    importedAt: importedAt,
  );

  @override
  List<Object?> get props => [id, title, filePath, lastPage, pageCount, importedAt];
}
