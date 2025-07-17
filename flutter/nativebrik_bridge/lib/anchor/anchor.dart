import 'package:flutter/material.dart';
import '../provider.dart';

/// A widget that acts as an anchor point for tooltips or onboarding stories in the Nativebrik dashboard.
///
/// The [NativebrikAnchor] registers its position and key with the Nativebrik provider, allowing
/// external overlays (such as tooltips or onboarding highlights) to be precisely positioned
/// relative to this widget. This is useful for guiding users through features or workflows
/// as part of an onboarding experience.
///
/// reference: https://docs.nativebrik.com/reference/flutter/nativebrikanchor
///
/// Usage:
/// Wrap any widget you want to highlight with [NativebrikAnchor], providing a unique [id].
/// The Nativebrik dashboard can then use this anchor to display contextual UI, such as a tooltip
/// or story step, at the correct location.
///
/// Example:
/// ```dart
/// NativebrikAnchor(
///   'unique-feature-id',
///   child: MyFeatureWidget(),
/// )
/// ```
class NativebrikAnchor extends StatefulWidget {
  final String id;
  final Widget child;

  const NativebrikAnchor(
    this.id, {
    super.key,
    required this.child,
  });

  @override
  // ignore: library_private_types_in_public_api
  _AnchorState createState() => _AnchorState();
}

class _AnchorState extends State<NativebrikAnchor> {
  final GlobalKey childKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Register the key after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.nativebrikProvider;
      if (provider != null) {
        provider.storeKey(widget.id, childKey);
      }
    });
  }

  @override
  void dispose() {
    // Remove the key when the widget is disposed
    final provider = context.nativebrikProvider;
    if (provider != null) {
      provider.removeKey(widget.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: childKey,
      child: widget.child,
    );
  }
}
