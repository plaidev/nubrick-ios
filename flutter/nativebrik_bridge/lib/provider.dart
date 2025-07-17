import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:nativebrik_bridge/tooltip/overlay.dart';

/// NativebrikProvider is the main provider for the Nativebrik SDK.
///
/// reference: https://docs.nativebrik.com/reference/flutter/nativebrikprovider
///
/// Usage:
/// ```dart
/// NativebrikProvider(
///   child: App(),
/// )
/// ```
class NativebrikProvider extends StatefulWidget {
  final Widget child;
  const NativebrikProvider({super.key, required this.child});

  @override
  State<NativebrikProvider> createState() => NativebrikProviderState();
}

class NativebrikProviderState extends State<NativebrikProvider> {
  final Map<String, GlobalKey> _keys = {};

  /// Get a global key by ID
  GlobalKey? getKey(String id) => _keys[id];

  /// Store a global key with an ID
  void storeKey(String id, GlobalKey key) {
    _keys[id] = key;
  }

  /// Remove a global key by ID
  void removeKey(String id) {
    _keys.remove(id);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        _render(context),
        NativebrikTooltipOverlay(keysReference: _keys),
      ],
    );
  }

  Widget _render(BuildContext context) {
    const String viewType = "nativebrik-overlay-view";
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        // overlay view controller will be attached when the nativebrik bridge plugin is intialized.
        return const SizedBox.shrink();
      case TargetPlatform.android:
        // to support in-app-messeging for android, we need to attach the overlay view into the flutter widget tree.
        return const SizedBox(
          height: 1,
          width: 1,
          child: AndroidView(
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: <String, dynamic>{},
            creationParamsCodec: StandardMessageCodec(),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Extension to access NativebrikProvider from build context
extension NativebrikProviderExtension on BuildContext {
  NativebrikProviderState? get nativebrikProvider {
    return findAncestorStateOfType<NativebrikProviderState>();
  }
}
