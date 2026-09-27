import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/device/device_posture.dart';
import '../../../../core/device/device_posture_cubit.dart';

/// Debug-only: fakes hinge angles so laptop mode (FR-2) can be exercised in
/// the iOS Simulator.
class PostureSimulatorButton extends StatelessWidget {
  const PostureSimulatorButton({super.key});

  static const _presets = <String, double?>{
    'Hardware reading': null,
    'Flat (180°)': 180,
    'Laptop mode (110°)': 110,
    'Closed (30°)': 30,
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DevicePostureCubit>();
    return PopupMenuButton<String>(
      tooltip: 'Simulate device posture (debug)',
      icon: Icon(Icons.devices_fold_outlined, color: cubit.isSimulated ? Theme.of(context).colorScheme.tertiary : null),
      onSelected: (label) {
        final angle = _presets[label];
        cubit.simulate(label == 'Hardware reading' ? null : DevicePosture.fromHingeAngle(angle));
      },
      itemBuilder: (context) => [for (final label in _presets.keys) PopupMenuItem(value: label, child: Text(label))],
    );
  }
}
