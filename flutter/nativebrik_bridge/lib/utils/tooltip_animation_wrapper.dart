import 'package:flutter/material.dart';

class TooltipAnimationWrapper extends StatefulWidget {
  final Offset anchorPosition;
  final Size anchorSize;
  final Size tooltipSize;
  final Size? previousAnchorSize;
  final Offset? previousAnchorPosition;
  final Widget Function(
    BuildContext context,
    Animation<double> fadeAnim,
    Animation<double> scaleAnim,
    Offset animatedAnchorPos,
    Size animatedAnchorSize,
  ) builder;
  final Duration popupDuration;
  final Duration moveDuration;
  final bool animateMove;

  const TooltipAnimationWrapper({
    super.key,
    required this.anchorPosition,
    required this.anchorSize,
    required this.tooltipSize,
    this.previousAnchorPosition,
    this.previousAnchorSize,
    required this.builder,
    this.popupDuration = const Duration(milliseconds: 200),
    this.moveDuration = const Duration(milliseconds: 200),
    this.animateMove = false,
  });

  @override
  State<TooltipAnimationWrapper> createState() =>
      _TooltipAnimationWrapperState();
}

class _TooltipAnimationWrapperState extends State<TooltipAnimationWrapper>
    with TickerProviderStateMixin {
  late final AnimationController _popupController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  late AnimationController _moveController;
  Animation<Offset>? _positionAnim;
  Animation<Size>? _sizeAnim;

  @override
  void initState() {
    super.initState();
    _popupController = AnimationController(
      vsync: this,
      duration: widget.popupDuration,
    );
    final curve =
        CurvedAnimation(parent: _popupController, curve: Curves.easeOutBack);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(curve);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _popupController.forward(from: 0.0);

    _moveController = AnimationController(
      vsync: this,
      duration: widget.moveDuration,
    );
    if (widget.animateMove &&
        widget.previousAnchorPosition != null &&
        widget.previousAnchorSize != null) {
      _positionAnim = Tween<Offset>(
        begin: widget.previousAnchorPosition!,
        end: widget.anchorPosition,
      ).animate(
          CurvedAnimation(parent: _moveController, curve: Curves.easeInOut));
      _sizeAnim = Tween<Size>(
        begin: widget.previousAnchorSize!,
        end: widget.anchorSize,
      ).animate(
          CurvedAnimation(parent: _moveController, curve: Curves.easeInOut));
      _moveController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant TooltipAnimationWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateMove &&
        (widget.anchorPosition != oldWidget.anchorPosition ||
            widget.anchorSize != oldWidget.anchorSize)) {
      _positionAnim = Tween<Offset>(
        begin: oldWidget.anchorPosition,
        end: widget.anchorPosition,
      ).animate(
          CurvedAnimation(parent: _moveController, curve: Curves.easeInOut));
      _sizeAnim = Tween<Size>(
        begin: oldWidget.anchorSize,
        end: widget.anchorSize,
      ).animate(
          CurvedAnimation(parent: _moveController, curve: Curves.easeInOut));
      _moveController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _popupController.dispose();
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_popupController, _moveController]),
      builder: (context, child) {
        final Offset anchorPos =
            _positionAnim != null && _moveController.isAnimating
                ? _positionAnim!.value
                : widget.anchorPosition;
        final Size anchorSize = _sizeAnim != null && _moveController.isAnimating
            ? _sizeAnim!.value
            : widget.anchorSize;
        return widget.builder(
            context, _fadeAnim, _scaleAnim, anchorPos, anchorSize);
      },
    );
  }
}
