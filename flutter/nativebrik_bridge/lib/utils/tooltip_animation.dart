import 'package:flutter/material.dart';

class AnimationFrame extends StatefulWidget {
  final Offset position;
  final Size size;
  final bool animateHole;

  final Widget Function(
    BuildContext context,
    Offset position,
    Size size,
    Animation<double> fade,
    Animation<double> scale,
    double hole,
  ) builder;

  const AnimationFrame({
    super.key,
    required this.position,
    required this.size,
    required this.builder,
    this.animateHole = false,
  });

  @override
  State<AnimationFrame> createState() => _AnimationFrameState();
}

class _AnimationFrameState extends State<AnimationFrame>
    with TickerProviderStateMixin {
  late final AnimationController _holeAnimController;
  late final Animation<double> _holeAnim;

  late final AnimationController _popupController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  late final AnimationController _translateController;
  Animation<Offset>? _positionAnim;
  Animation<Size>? _sizeAnim;

  @override
  void initState() {
    super.initState();
    _holeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _holeAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.6).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.6, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 50,
      ),
    ]).animate(_holeAnimController);
    if (widget.animateHole) {
      _holeAnimController.repeat();
    }

    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _popupController, curve: Curves.easeOutBack));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _popupController, curve: Curves.easeOutBack));
    _popupController.forward(from: 0.0);

    _translateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _positionAnim =
        Tween<Offset>(begin: widget.position, end: widget.position).animate(
      CurvedAnimation(parent: _translateController, curve: Curves.easeInOut),
    );
    _sizeAnim = Tween<Size>(begin: widget.size, end: widget.size).animate(
      CurvedAnimation(parent: _translateController, curve: Curves.easeInOut),
    );
    _translateController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant AnimationFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _positionAnim = Tween<Offset>(
      begin: oldWidget.position,
      end: widget.position,
    ).animate(
      CurvedAnimation(parent: _translateController, curve: Curves.easeInOut),
    );
    _sizeAnim = Tween<Size>(
      begin: oldWidget.size,
      end: widget.size,
    ).animate(
      CurvedAnimation(parent: _translateController, curve: Curves.easeInOut),
    );
    _translateController.forward(from: 0.0);

    if (widget.animateHole) {
      _holeAnimController.repeat();
    } else {
      _holeAnimController.reset();
    }
  }

  @override
  void dispose() {
    _holeAnimController.dispose();
    _popupController.dispose();
    _translateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_popupController, _translateController, _holeAnimController]),
      builder: (context, child) {
        return widget.builder(
          context,
          _positionAnim!.value,
          _sizeAnim!.value,
          _fadeAnim,
          _scaleAnim,
          _holeAnim.value,
        );
      },
    );
  }
}
