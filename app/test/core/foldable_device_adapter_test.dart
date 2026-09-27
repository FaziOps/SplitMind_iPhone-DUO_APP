import 'package:flutter_test/flutter_test.dart';
import 'package:splitmind/core/device/device_posture.dart';
import 'package:splitmind/core/device/device_posture_cubit.dart';
import 'package:splitmind/core/device/foldable_device_adapter.dart';

void main() {
  group('PlatformFoldableDeviceAdapter.parse', () {
    test('non-foldable and malformed payloads map to nonFoldable', () {
      expect(PlatformFoldableDeviceAdapter.parse(null), DevicePosture.nonFoldable);
      expect(PlatformFoldableDeviceAdapter.parse('garbage'), DevicePosture.nonFoldable);
      expect(PlatformFoldableDeviceAdapter.parse({'isFoldable': false, 'hingeAngle': 110}), DevicePosture.nonFoldable);
    });

    test('translates hinge angles into fold states', () {
      expect(
        PlatformFoldableDeviceAdapter.parse({'isFoldable': true, 'hingeAngle': 110}).foldState,
        FoldState.halfFolded,
      );
      expect(PlatformFoldableDeviceAdapter.parse({'isFoldable': true, 'hingeAngle': 180.0}).foldState, FoldState.flat);
      expect(PlatformFoldableDeviceAdapter.parse({'isFoldable': true}).foldState, FoldState.flat);
    });
  });

  test('DevicePostureCubit follows the adapter unless simulated', () async {
    final adapter = SimulatedFoldableDeviceAdapter();
    final cubit = DevicePostureCubit(adapter);

    adapter.emit(DevicePosture.fromHingeAngle(180));
    await pumpEventQueue();
    expect(cubit.state.foldState, FoldState.flat);

    cubit.simulate(DevicePosture.fromHingeAngle(110));
    adapter.emit(DevicePosture.fromHingeAngle(170));
    await pumpEventQueue();
    expect(cubit.state.isLaptopMode, isTrue);

    cubit.simulate(null);
    expect(cubit.state.hingeAngle, 170);
    await cubit.close();
  });
}
