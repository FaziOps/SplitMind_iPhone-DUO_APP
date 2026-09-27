import 'dart:async';

import 'package:flutter/services.dart';

import 'device_posture.dart';

/// Adapter pattern (PRD Section 3): the app never talks to iOS hinge APIs
/// directly. Implementations translate raw sensor data into [DevicePosture].
abstract class FoldableDeviceAdapter {
  DevicePosture get current;
  Stream<DevicePosture> get postureChanges;
  Future<void> dispose();
}

/// Reads posture from the native `app.splitmind/device_posture` event channel
/// (see ios/Runner/AppDelegate.swift).
///
/// Payload: `{"isFoldable": bool, "hingeAngle": double?}`. When the channel is
/// missing or fails (tests, older builds) the device is treated as a standard
/// iPhone, which is always a safe layout.
class PlatformFoldableDeviceAdapter implements FoldableDeviceAdapter {
  PlatformFoldableDeviceAdapter({EventChannel? channel})
    : _channel = channel ?? const EventChannel('app.splitmind/device_posture');

  final EventChannel _channel;
  final _controller = StreamController<DevicePosture>.broadcast();
  StreamSubscription<dynamic>? _subscription;
  DevicePosture _current = DevicePosture.nonFoldable;

  @override
  DevicePosture get current => _current;

  @override
  Stream<DevicePosture> get postureChanges {
    _subscription ??= _channel.receiveBroadcastStream().listen(
      (raw) => _emit(parse(raw)),
      onError: (Object _) => _emit(DevicePosture.nonFoldable),
    );
    return _controller.stream;
  }

  static DevicePosture parse(Object? raw) {
    if (raw is! Map || raw['isFoldable'] != true) return DevicePosture.nonFoldable;
    final angle = raw['hingeAngle'];
    return DevicePosture.fromHingeAngle(angle is num ? angle.toDouble() : null);
  }

  void _emit(DevicePosture posture) {
    if (posture == _current) return;
    _current = posture;
    _controller.add(posture);
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}

/// Manually driven adapter for tests.
class SimulatedFoldableDeviceAdapter implements FoldableDeviceAdapter {
  SimulatedFoldableDeviceAdapter([this._current = DevicePosture.nonFoldable]);

  final _controller = StreamController<DevicePosture>.broadcast();
  DevicePosture _current;

  @override
  DevicePosture get current => _current;

  @override
  Stream<DevicePosture> get postureChanges => _controller.stream;

  void emit(DevicePosture posture) {
    _current = posture;
    _controller.add(posture);
  }

  @override
  Future<void> dispose() => _controller.close();
}
