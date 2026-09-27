import 'package:flutter/material.dart';

/// Two panes split along [axis]: horizontal for side by side (FR-1), vertical
/// for laptop mode (FR-2).
class DualPaneLayout extends StatelessWidget {
  const DualPaneLayout({super.key, required this.primary, required this.secondary, required this.axis});

  final Widget primary;
  final Widget secondary;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final divider = axis == Axis.horizontal ? const VerticalDivider(width: 1) : const Divider(height: 1);
    return Flex(
      direction: axis,
      children: [
        Expanded(child: primary),
        divider,
        Expanded(child: secondary),
      ],
    );
  }
}
