import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nativebrik_bridge/channel/nativebrik_bridge_platform_interface.dart';
import 'package:nativebrik_bridge/nativebrik_bridge.dart';
import 'package:flutter/material.dart';
import 'package:nativebrik_bridge/utils/random.dart';
import 'package:nativebrik_bridge/utils/tooltip_position.dart';
import 'package:nativebrik_bridge/schema/generated.dart' as schema;
import 'package:nativebrik_bridge/utils/tooltip_animation_wrapper.dart';

class NativebrikTooltip extends StatefulWidget {
  final Map<String, GlobalKey> keysReference;
  const NativebrikTooltip({super.key, required this.keysReference});

  @override
  State<NativebrikTooltip> createState() => NativebrikTooltipState();
}

class NativebrikTooltipState extends State<NativebrikTooltip>
    with TickerProviderStateMixin {
  schema.UIRootBlock? _rootBlock;
  final String _channelId = generateRandomString(16);
  String? _currentAnchorId;
  Offset? _anchorPosition;
  Size? _anchorSize;
  Size? _lastTooltipSize;

  Offset? _animStartPosition;
  Size? _animStartSize;
  bool _animateMove = false;

  void _onDispatch(String name) async {
    print("NativebrikTooltipState _onDispatch: $name");
    var uiroot = await NativebrikBridgePlatform.instance.connectTooltip(name);
    print("NativebrikTooltipState _onDispatch: $uiroot");
    if (uiroot == null) {
      return;
    }
    _rootBlock = uiroot;
    var currentPageId = uiroot.data?.currentPageId;
    if (currentPageId == null) {
      return;
    }
    print("NativebrikTooltipState _onDispatch.currentPageId: $currentPageId");
    var page =
        uiroot.data?.pages?.firstWhere((page) => page.id == currentPageId);
    if (page == null) {
      return;
    }
    var destinationId = page.data?.triggerSetting?.onTrigger?.destinationPageId;
    if (destinationId == null) {
      return;
    }
    _setupTooltip(destinationId);
  }

  void _setupTooltip(String pageId) async {
    var page = _rootBlock?.data?.pages?.firstWhere((page) => page.id == pageId);
    if (page == null) {
      return;
    }
    var anchorId = page.data?.tooltipAnchor;
    if (anchorId == null) {
      return;
    }
    var tooltipSize = page.data?.tooltipSize;
    if (tooltipSize == null) {
      return;
    }
    final tooltipSizeValue = (tooltipSize.width != null &&
            tooltipSize.height != null)
        ? Size(tooltipSize.width!.toDouble(), tooltipSize.height!.toDouble())
        : null;
    if (tooltipSizeValue == null) return;
    print("NativebrikTooltipState _setupTooltip.anchorId: $anchorId");
    final key = widget.keysReference[anchorId];
    if (key == null) {
      return;
    }
    final context = key.currentContext;
    if (context == null) {
      return;
    }
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;

    if (_channelId.isNotEmpty) {
      await NativebrikBridgePlatform.instance
          .disconnectTooltipEmbedding(_channelId);
    }
    await NativebrikBridgePlatform.instance.connectTooltipEmbedding(
      _channelId,
      schema.UIRootBlock(
        id: generateRandomString(16),
        data: schema.UIRootBlockData(
          pages: _rootBlock?.data?.pages,
          currentPageId: pageId,
        ),
      ),
    );

    setState(() {
      _currentAnchorId = anchorId;
      _anchorPosition = position;
      _anchorSize = size;
      _lastTooltipSize = tooltipSizeValue;
      _animStartPosition = position;
      _animStartSize = size;
      _animateMove = false;
    });
  }

  void _onNextTooltip(String nextAnchorId) async {
    print("NativebrikTooltipState _onNextTooltip: $nextAnchorId");
    final key = widget.keysReference[nextAnchorId];
    if (key == null) {
      return;
    }
    print("NativebrikTooltipState _onNextTooltip.key: $key");
    final context = key.currentContext;
    if (context == null) {
      return;
    }
    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;
    // Animate from current to new position/size
    _animStartPosition = _anchorPosition;
    _animStartSize = _anchorSize;
    setState(() {
      _currentAnchorId = nextAnchorId;
      _anchorPosition = position;
      _anchorSize = size;
      _animateMove = true;
    });
  }

  void _hideTooltip() {
    if (_channelId.isNotEmpty) {
      NativebrikBridgePlatform.instance.disconnectTooltipEmbedding(_channelId);
    }
    setState(() {
      _currentAnchorId = null;
      _anchorPosition = null;
      _anchorSize = null;
      _rootBlock = null;
    });
  }

  void _onAnchorTap() {
    // Default behavior: hide the tooltip
    _hideTooltip();
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'on-next-tooltip':
        final nextAnchorId = call.arguments as String?;
        if (nextAnchorId == null) return Future.value(false);
        print(
            "NativebrikTooltipState _handleMethod on-next-tooltip: $nextAnchorId");
        _onNextTooltip(nextAnchorId);
        return Future.value(true);
      case 'on-dismiss-tooltip':
        print("NativebrikTooltipState _handleMethod on-dismiss-tooltip");
        _hideTooltip();
        return Future.value(true);
      default:
        return Future.value(false);
    }
  }

  @override
  void initState() {
    super.initState();
    print("NativebrikTooltipState initState add ons dispatch listener");
    final MethodChannel channel =
        MethodChannel("Nativebrik/Embedding/$_channelId");
    channel.setMethodCallHandler(_handleMethod);
    NativebrikBridge.instance?.addOnDispatchListener(_onDispatch);
  }

  @override
  void dispose() {
    print("NativebrikTooltipState dispose remove on dispatch listener");
    NativebrikBridge.instance?.removeOnDispatchListener(_onDispatch);
    if (_channelId.isNotEmpty) {
      NativebrikBridgePlatform.instance.disconnectTooltipEmbedding(_channelId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _renderTooltip(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _renderTooltip(BuildContext context) {
    Widget tooltipWidget = const SizedBox.shrink();

    if (_anchorPosition != null &&
        _anchorSize != null &&
        _currentAnchorId != null &&
        _lastTooltipSize != null) {
      final screenSize = MediaQuery.of(context).size;
      tooltipWidget = TooltipAnimationWrapper(
        anchorPosition: _anchorPosition!,
        anchorSize: _anchorSize!,
        tooltipSize: _lastTooltipSize!,
        previousAnchorPosition: _animateMove ? _animStartPosition : null,
        previousAnchorSize: _animateMove ? _animStartSize : null,
        animateMove: _animateMove,
        builder: (context, fadeAnim, scaleAnim, animatedAnchorPos,
            animatedAnchorSize) {
          final Offset tooltipPos = calculateTooltipPosition(
            anchorPosition: animatedAnchorPos,
            anchorSize: animatedAnchorSize,
            tooltipSize: _lastTooltipSize!,
            screenSize: screenSize,
            preferBelow: true,
            margin: 16,
          );
          return Transform.translate(
            offset: tooltipPos,
            child: FadeTransition(
              opacity: fadeAnim,
              child: ScaleTransition(
                scale: scaleAnim,
                child: Material(
                  color: Colors.transparent,
                  elevation: 99999,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: _lastTooltipSize!.width,
                    height: _lastTooltipSize!.height,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                          spreadRadius: 16,
                        ),
                      ],
                    ),
                    child: _renderEmbedding(context),
                  ),
                ),
              ),
            ),
          );
        },
      );
      // Custom barrier with transparent hole over anchor
      return Stack(
        children: [
          TooltipAnimationWrapper(
            anchorPosition: _anchorPosition!,
            anchorSize: _anchorSize!,
            tooltipSize: _lastTooltipSize!,
            previousAnchorPosition: _animateMove ? _animStartPosition : null,
            previousAnchorSize: _animateMove ? _animStartSize : null,
            animateMove: _animateMove,
            builder: (context, _fadeAnim, _scaleAnim, animatedAnchorPos,
                animatedAnchorSize) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final tapPos = details.globalPosition;
                  final anchorRect = Rect.fromLTWH(
                    animatedAnchorPos.dx,
                    animatedAnchorPos.dy,
                    animatedAnchorSize.width,
                    animatedAnchorSize.height,
                  ).inflate(8.0);
                  final anchorRRect = RRect.fromRectAndRadius(
                      anchorRect, const Radius.circular(8.0));
                  if (anchorRRect.contains(tapPos)) {
                    _onAnchorTap();
                  }
                  // Else, absorb tap (do nothing)
                },
                child: CustomPaint(
                  size: screenSize,
                  painter: _BarrierWithHolePainter(
                    anchorRect: Rect.fromLTWH(
                      animatedAnchorPos.dx,
                      animatedAnchorPos.dy,
                      animatedAnchorSize.width,
                      animatedAnchorSize.height,
                    ).inflate(8.0),
                    borderRadius: 8.0,
                    color: const Color.fromARGB(30, 0, 0, 0),
                  ),
                ),
              );
            },
          ),
          tooltipWidget,
        ],
      );
    }

    return tooltipWidget;
  }

  Widget _renderEmbedding(BuildContext context) {
    print("NativebrikTooltipState _renderEmbedding: $_channelId");
    if (_channelId.isEmpty) {
      return const SizedBox.shrink();
    }
    const String viewType = "nativebrik-embedding-view";
    final Map<String, dynamic> creationParams = <String, dynamic>{
      "channelId": _channelId,
      "arguments": {},
    };
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// Custom painter for the barrier with a transparent hole
class _BarrierWithHolePainter extends CustomPainter {
  final Rect anchorRect;
  final double borderRadius;
  final Color color;
  _BarrierWithHolePainter(
      {required this.anchorRect,
      required this.borderRadius,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
          RRect.fromRectAndRadius(anchorRect, Radius.circular(borderRadius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
