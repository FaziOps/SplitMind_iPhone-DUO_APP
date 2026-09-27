import 'package:file_picker/file_picker.dart';

class PickedDocument {
  const PickedDocument({required this.path, required this.name});

  final String path;
  final String name;
}

abstract class DocumentPicker {
  /// Returns null when the user cancels.
  Future<PickedDocument?> pickPdf();
}

/// Uses the iOS document picker, which needs no permission prompt (FR-10:
/// permissions are requested only when needed).
class FilePickerDocumentPicker implements DocumentPicker {
  const FilePickerDocumentPicker();

  @override
  Future<PickedDocument?> pickPdf() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
    final path = file?.path;
    if (file == null || path == null) return null;
    return PickedDocument(path: path, name: file.name);
  }
}
