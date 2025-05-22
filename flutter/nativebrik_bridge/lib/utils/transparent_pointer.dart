import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

class TransparentPointer extends SingleChildRenderObjectWidget {
  final bool transparent;
  const TransparentPointer({
    super.key,
    required super.child,
    this.transparent = true,
  });

  @override
  RenderObject createRenderObject(BuildContext _) =>
      _RenderTransparentPointer(transparent: transparent);

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderTransparentPointer renderObject) {
    renderObject.transparent = transparent;
  }
}

class _RenderTransparentPointer extends RenderProxyBox {
  _RenderTransparentPointer({required bool transparent})
      : _transparent = transparent;

  bool _transparent;
  bool get transparent => _transparent;
  set transparent(bool value) {
    if (_transparent != value) {
      _transparent = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hit = super.hitTest(result, position: position);
    return transparent ? false : hit;
  }
}
