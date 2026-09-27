/// Hardcoded screen ratios and UI thresholds (PRD: core/constants).
abstract final class LayoutConstants {
  /// Widths at or above this render the side-by-side dual-pane layout (FR-1).
  static const double dualPaneMinWidth = 600;

  /// Hinge angles (degrees) in this range snap to laptop mode (FR-2).
  static const double laptopModeMinHingeAngle = 90;
  static const double laptopModeMaxHingeAngle = 135;

  /// Floating AI overlay sizes on single screens, as fractions of height.
  static const double overlayInitialSize = 0.55;
  static const double overlayMinSize = 0.25;
  static const double overlayMaxSize = 0.92;
}

abstract final class AiConstants {
  /// NFR-5: only the last AI request within this window is sent.
  static const Duration dispatchDebounce = Duration(milliseconds: 600);

  /// Must match the backend's MAX_TEXT_CHARS.
  static const int maxPassageChars = 8000;

  /// Must match the backend's MAX_QUESTION_CHARS.
  static const int maxQuestionChars = 500;
}
