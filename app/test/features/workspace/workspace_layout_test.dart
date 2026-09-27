import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitmind/core/device/device_posture.dart';
import 'package:splitmind/features/workspace/presentation/widgets/workspace_layout.dart';

void main() {
  const outer = Size(375, 812); // 5.4" outer display / standard iPhone
  const inner = Size(760, 900); // unfolded inner display

  test('standard iPhone uses the single-pane overlay layout (FR-1a)', () {
    expect(resolveWorkspaceLayout(size: outer, posture: DevicePosture.nonFoldable), WorkspaceLayoutMode.single);
  });

  test('wide unfolded display renders side by side (FR-1)', () {
    expect(
      resolveWorkspaceLayout(size: inner, posture: DevicePosture.fromHingeAngle(180)),
      WorkspaceLayoutMode.sideBySide,
    );
  });

  test('hinge between 90 and 135 degrees snaps to laptop mode (FR-2)', () {
    for (final angle in [90.0, 110.0, 135.0]) {
      expect(
        resolveWorkspaceLayout(size: inner, posture: DevicePosture.fromHingeAngle(angle)),
        WorkspaceLayoutMode.stacked,
        reason: '$angle°',
      );
    }
    expect(
      resolveWorkspaceLayout(size: inner, posture: DevicePosture.fromHingeAngle(136)),
      WorkspaceLayoutMode.sideBySide,
    );
  });

  test('closed hinge falls back to single pane', () {
    expect(resolveWorkspaceLayout(size: inner, posture: DevicePosture.fromHingeAngle(30)), WorkspaceLayoutMode.single);
  });

  test('a half-opened horizontal DisplayFeature also means laptop mode', () {
    const fold = DisplayFeature(
      bounds: Rect.fromLTWH(0, 440, 760, 20),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    );
    expect(
      resolveWorkspaceLayout(size: inner, posture: DevicePosture.nonFoldable, displayFeatures: const [fold]),
      WorkspaceLayoutMode.stacked,
    );
  });
}
