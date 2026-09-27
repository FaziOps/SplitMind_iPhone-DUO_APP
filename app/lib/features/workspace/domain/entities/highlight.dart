import 'package:equatable/equatable.dart';

/// A passage selected in the reader, with enough provenance to cite it later
/// (FR-8).
class Highlight extends Equatable {
  const Highlight({required this.text, this.docId, this.docTitle, this.pageNumber});

  final String text;
  final String? docId;
  final String? docTitle;
  final int? pageNumber;

  /// "p. 4 · Paper title", or null when there is no provenance.
  String? get citation {
    final parts = [if (pageNumber != null) 'p. $pageNumber', ?docTitle];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  List<Object?> get props => [text, docId, docTitle, pageNumber];
}
