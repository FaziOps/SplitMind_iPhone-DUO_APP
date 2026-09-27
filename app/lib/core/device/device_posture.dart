import 'package:equatable/equatable.dart';

import '../constants/app_constants.dart';

/// Hardware-independent fold states produced by a FoldableDeviceAdapter.
enum FoldState {
  /// Fully open, or a device without a hinge.
  flat,

  /// Hinge between 90° and 135°: "laptop mode" (FR-2).
  halfFolded,

  /// Hinge below 90°: the inner display is effectively not in use.
  closed;

  static FoldState fromHingeAngle(double? degrees) {
    if (degrees == null) return FoldState.flat;
    if (degrees < LayoutConstants.laptopModeMinHingeAngle) return FoldState.closed;
    if (degrees <= LayoutConstants.laptopModeMaxHingeAngle) return FoldState.halfFolded;
    return FoldState.flat;
  }
}

class DevicePosture extends Equatable {
  const DevicePosture({required this.isFoldable, required this.foldState, this.hingeAngle});

  factory DevicePosture.fromHingeAngle(double? degrees, {bool isFoldable = true}) {
    return DevicePosture(isFoldable: isFoldable, foldState: FoldState.fromHingeAngle(degrees), hingeAngle: degrees);
  }

  /// A standard (non-foldable) iPhone.
  static const nonFoldable = DevicePosture(isFoldable: false, foldState: FoldState.flat);

  final bool isFoldable;
  final FoldState foldState;
  final double? hingeAngle;

  bool get isLaptopMode => foldState == FoldState.halfFolded;

  @override
  List<Object?> get props => [isFoldable, foldState, hingeAngle];
}
