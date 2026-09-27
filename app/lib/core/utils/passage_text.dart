/// Text extracted from a PDF keeps the page's line breaks and column padding.
/// Collapses them so a passage reads as flowing prose in the notes pane and in
/// the prompt.
String normalizePassage(String raw) => raw.replaceAll(RegExp(r'\s+'), ' ').trim();
