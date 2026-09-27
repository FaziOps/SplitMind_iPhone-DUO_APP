import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Size;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/device/device_posture.dart';

enum WorkspaceLayoutMode {
  /// Reader full screen; AI notes in a floating overlay (5.4" / standard iPhone).
  single,

  /// Reader left, notes right (unfolded 7.6" display).
  sideBySide,

  /// Reader top, notes bottom (laptop mode, hinge 90°–135°).
  stacked,
}

/// Chooses the workspace layout (FR-1, FR-1a, FR-2). Pure so it can be tested
/// without a device.
///
/// Posture comes from two sources: the FoldableDeviceAdapter's hinge angle, and
/// Flutter's [DisplayFeature]s, which report a half-opened fold on platforms
/// that expose one.
WorkspaceLayoutMode resolveWorkspaceLayout({
  required Size size,
  required DevicePosture posture,
  List<DisplayFeature> displayFeatures = const [],
}) {
  if (posture.isLaptopMode || _hasHalfOpenedHorizontalFold(displayFeatures)) {
    return WorkspaceLayoutMode.stacked;
  }
  if (posture.foldState != FoldState.closed && size.width >= LayoutConstants.dualPaneMinWidth) {
    return WorkspaceLayoutMode.sideBySide;
  }
  return WorkspaceLayoutMode.single;
}

bool _hasHalfOpenedHorizontalFold(List<DisplayFeature> features) {
  return features.any(
    (f) =>
        (f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge) &&
        f.state == DisplayFeatureState.postureHalfOpened &&
        f.bounds.width > f.bounds.height,
  );
}
