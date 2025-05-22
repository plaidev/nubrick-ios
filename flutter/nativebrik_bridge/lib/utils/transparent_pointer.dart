import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

class TransparentPointer extends SingleChildRenderObjectWidget {
  final bool transparent;
  final Rect? transparentRect;
  const TransparentPointer({
    super.key,
    required super.child,
    this.transparent = true,
    this.transparentRect,
  });

  @override
  RenderObject createRenderObject(BuildContext _) => _RenderTransparentPointer(
        transparent: transparent,
        transparentRect: transparentRect,
      );

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderTransparentPointer renderObject) {
    renderObject.transparent = transparent;
    renderObject.transparentRect = transparentRect;
  }
}

class _RenderTransparentPointer extends RenderProxyBox {
  _RenderTransparentPointer({
    required bool transparent,
    Rect? transparentRect,
  })  : _transparent = transparent,
        _transparentRect = transparentRect;

  bool _transparent;
  bool get transparent => _transparent;
  set transparent(bool value) {
    if (_transparent != value) {
      _transparent = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  Rect? _transparentRect;
  Rect? get transparentRect => _transparentRect;
  set transparentRect(Rect? value) {
    if (_transparentRect != value) {
      _transparentRect = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hit = super.hitTest(result, position: position);

    if (_transparent) {
      if (_transparentRect != null) {
        // Only transparent within the specified rect
        return !_transparentRect!.contains(position) && hit;
      }
      // Fully transparent behavior
      return false;
    }

    return hit;
  }
}
