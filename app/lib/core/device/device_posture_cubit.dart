import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'device_posture.dart';
import 'foldable_device_adapter.dart';

/// Exposes the adapter's posture to the widget tree.
///
/// [simulate] overrides the hardware reading so laptop mode can be exercised
/// in the iOS Simulator, which has no hinge. Only debug-mode UI calls it.
class DevicePostureCubit extends Cubit<DevicePosture> {
  DevicePostureCubit(this._adapter) : super(_adapter.current) {
    _hardware = _adapter.current;
    _subscription = _adapter.postureChanges.listen((posture) {
      _hardware = posture;
      if (_override == null) emit(posture);
    });
  }

  final FoldableDeviceAdapter _adapter;
  late final StreamSubscription<DevicePosture> _subscription;
  late DevicePosture _hardware;
  DevicePosture? _override;

  bool get isSimulated => _override != null;

  void simulate(DevicePosture? posture) {
    _override = posture;
    emit(posture ?? _hardware);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
