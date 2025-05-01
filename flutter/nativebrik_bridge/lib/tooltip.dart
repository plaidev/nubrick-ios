import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nativebrik_bridge/channel/nativebrik_bridge_platform_interface.dart';
import 'package:nativebrik_bridge/nativebrik_bridge.dart';
import 'package:flutter/material.dart';
import 'package:nativebrik_bridge/utils/random.dart';
import 'package:nativebrik_bridge/utils/tooltip_position.dart';
import 'package:nativebrik_bridge/schema/generated.dart' as schema;
import 'package:nativebrik_bridge/utils/tooltip_animation.dart';

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
  schema.UIPageBlock? _currentPage;
  bool _isAnimateHole = false;
  Offset? _anchorPosition;
  Size? _anchorSize;
  Offset? _tooltipPosition;
  Size? _tooltipSize;

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
    await NativebrikBridgePlatform.instance.connectTooltipEmbedding(
        _channelId,
        schema.UIRootBlock(
          id: generateRandomString(16),
          data: schema.UIRootBlockData(
            currentPageId: destinationId,
            pages: uiroot.data?.pages,
          ),
        ));
    await Future.delayed(const Duration(milliseconds: 100));
    await _onNextTooltip(destinationId);
  }

  Future<void> _onNextTooltip(String pageId) async {
    // find the page
    var page =
        _rootBlock?.data?.pages?.firstWhere((element) => element.id == pageId);
    if (page == null) {
      return;
    }
    _currentPage = page;
    var anchorId = page.data?.tooltipAnchor;
    if (anchorId == null) {
      return;
    }
    print("NativebrikTooltipState _onNextTooltip: $pageId, $anchorId");
    final key = widget.keysReference[anchorId];
    if (key == null) {
      return;
    }
    print("NativebrikTooltipState _onNextTooltip.key: $key");
    final context = key.currentContext;
    if (context == null) {
      return;
    }
    if (!context.mounted) return;
    final tooltipSize = page.data?.tooltipSize;
    if (tooltipSize == null) {
      return;
    }
    final tooltipSizeValue = (tooltipSize.width != null &&
            tooltipSize.height != null)
        ? Size(tooltipSize.width!.toDouble(), tooltipSize.height!.toDouble())
        : null;
    if (tooltipSizeValue == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final anchorPosition = box.localToGlobal(Offset.zero);
    final anchorSize = box.size;
    final tooltipPosition = calculateTooltipPosition(
      anchorPosition: anchorPosition,
      anchorSize: anchorSize,
      tooltipSize: tooltipSizeValue,
      screenSize: MediaQuery.of(context).size,
      placement: page.data?.tooltipPlacement ??
          schema.UITooltipPlacement.BOTTOM_CENTER,
    );

    final willAnimateHole =
        getTransitionTarget(page) == schema.UITooltipTransitionTarget.ANCHOR &&
            page.data?.triggerSetting?.onTrigger != null;

    print(
        "NativebrikTooltipState _onNextTooltip.tooltipPosition: $tooltipPosition");
    setState(() {
      _anchorPosition = anchorPosition;
      _anchorSize = anchorSize;
      _tooltipPosition = tooltipPosition;
      _tooltipSize = tooltipSizeValue;
      _isAnimateHole = willAnimateHole;
    });
  }

  void _hideTooltip() {
    print("NativebrikTooltipState _hideTooltip");
    if (_channelId.isNotEmpty) {
      NativebrikBridgePlatform.instance.disconnectTooltipEmbedding(_channelId);
    }
    setState(() {
      _anchorPosition = null;
      _anchorSize = null;
      _tooltipPosition = null;
      _tooltipSize = null;
      _rootBlock = null;
      _currentPage = null;
    });
  }

  void _onTransitionTargetTap(bool isInAnchor) {
    print("NativebrikTooltipState _onTransitionTargetTap: $isInAnchor");
    if (_currentPage == null) {
      return;
    }
    if (_currentPage?.data?.kind != schema.PageKind.TOOLTIP) {
      return;
    }
    final target = getTransitionTarget(_currentPage);
    if (target == schema.UITooltipTransitionTarget.ANCHOR && !isInAnchor) {
      // if the transiation target is anchor, but the isInAnchor is not true, then do nothing.
      return;
    }
    var onTrigger = _currentPage?.data?.triggerSetting?.onTrigger;
    if (onTrigger == null) {
      return;
    }
    if (_channelId.isEmpty) {
      return;
    }
    NativebrikBridgePlatform.instance
        .callTooltipEmbeddingDispatch(_channelId, onTrigger);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'on-next-tooltip':
        final pageId = call.arguments["pageId"] as String;
        _onNextTooltip(pageId);
        return Future.value(true);
      case 'on-dismiss-tooltip':
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
    print(
        "NativebrikTooltipState _renderTooltip: $_anchorPosition, $_anchorSize, $_tooltipPosition, $_tooltipSize");
    if (_anchorPosition != null &&
        _anchorSize != null &&
        _tooltipPosition != null &&
        _tooltipSize != null) {
      final screenSize = MediaQuery.of(context).size;
      Widget tooltipWidget = AnimationFrame(
        position: _tooltipPosition!,
        size: _tooltipSize!,
        builder: (context, position, size, fade, scale, _) {
          return Transform.translate(
            offset: position,
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: Material(
                  color: Colors.transparent,
                  elevation: 99999,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: size.width,
                    height: size.height,
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
          AnimationFrame(
            position: _anchorPosition!,
            size: _anchorSize!,
            animateHole: _isAnimateHole,
            builder: (context, position, size, fade, scale, hole) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final tapPos = details.globalPosition;
                  final anchorRect = Rect.fromLTWH(
                    position.dx,
                    position.dy,
                    size.width,
                    size.height,
                  ).inflate(8.0);
                  final anchorRRect = RRect.fromRectAndRadius(
                      anchorRect, const Radius.circular(8.0));
                  if (anchorRRect.contains(tapPos)) {
                    _onTransitionTargetTap(true);
                  } else {
                    _onTransitionTargetTap(false);
                  }
                  // Else, absorb tap (do nothing)
                },
                child: CustomPaint(
                  size: screenSize,
                  painter: _BarrierWithHolePainter(
                    anchorRect: Rect.fromLTWH(
                      position.dx,
                      position.dy,
                      size.width,
                      size.height,
                    ).inflate(8.0 * hole),
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
    return const SizedBox.shrink();
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

schema.UITooltipTransitionTarget getTransitionTarget(schema.UIPageBlock? page) {
  return page?.data?.tooltipTransitionTarget ??
      schema.UITooltipTransitionTarget.ANCHOR;
}
