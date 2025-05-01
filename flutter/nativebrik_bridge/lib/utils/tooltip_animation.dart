import 'package:flutter/material.dart';

class AnimationFrame extends StatefulWidget {
  final Offset position;
  final Size size;

  final Widget Function(
    BuildContext context,
    Offset position,
    Size size,
    Animation<double> fade,
    Animation<double> scale,
  ) builder;

  const AnimationFrame({
    super.key,
    required this.position,
    required this.size,
    required this.builder,
  });

  @override
  State<AnimationFrame> createState() => _AnimationFrameState();
}

class _AnimationFrameState extends State<AnimationFrame>
    with TickerProviderStateMixin {
  late final AnimationController _popupController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  late final AnimationController _translateController;
  Animation<Offset>? _positionAnim;
  Animation<Size>? _sizeAnim;

  @override
  void initState() {
    super.initState();
    _popupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    final curve =
        CurvedAnimation(parent: _popupController, curve: Curves.easeOutBack);
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(curve);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
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
  }

  @override
  void dispose() {
    _popupController.dispose();
    _translateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_popupController, _translateController]),
      builder: (context, child) {
        return widget.builder(
          context,
          _positionAnim!.value,
          _sizeAnim!.value,
          _fadeAnim,
          _scaleAnim,
        );
      },
    );
  }
}
