import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

/// Slide-up AI panel for single screens (FR-1, FR-1a).
///
/// Unlike a modal bottom sheet it lives inside the workspace Stack, so the
/// reader above stays interactive (highlight while the panel is up) and a
/// fold or unfold never leaves an orphaned route on screen.
class FloatingNotesOverlay extends StatelessWidget {
  const FloatingNotesOverlay({super.key, required this.builder, required this.onClose});

  final Widget Function(BuildContext context, ScrollController controller) builder;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        // Dragged all the way down: treat as a dismiss.
        if (notification.extent <= notification.minExtent + 0.01) onClose();
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: LayoutConstants.overlayInitialSize,
        minChildSize: LayoutConstants.overlayMinSize,
        maxChildSize: LayoutConstants.overlayMaxSize,
        snap: true,
        builder: (context, controller) {
          return Material(
            elevation: 12,
            color: scheme.surface,
            shadowColor: scheme.shadow,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: builder(context, controller),
          );
        },
      ),
    );
  }
}
