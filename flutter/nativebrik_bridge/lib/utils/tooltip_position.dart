import 'package:flutter/widgets.dart';

/// Calculates the best position for a tooltip given the anchor and tooltip sizes/positions.
///
/// - [anchorPosition]: The global position (top-left) of the anchor widget.
/// - [anchorSize]: The size of the anchor widget.
/// - [tooltipSize]: The size of the tooltip widget.
/// - [screenSize]: The size of the screen.
/// - [preferBelow]: If true, prefer showing below the anchor; otherwise, above.
/// - [margin]: The minimum margin from the screen edges.
///
/// Returns the top-left Offset for the tooltip.
Offset calculateTooltipPosition({
  required Offset anchorPosition,
  required Size anchorSize,
  required Size tooltipSize,
  required Size screenSize,
  bool preferBelow = true,
  double margin = 16.0,
  double offset = 16.0,
}) {
  // Default: below anchor, horizontally centered
  double left = anchorPosition.dx + (anchorSize.width - tooltipSize.width) / 2;
  double top = anchorPosition.dy + anchorSize.height + offset;

  // If below would overflow, try above
  if (preferBelow && (top + tooltipSize.height >= screenSize.height - offset)) {
    top = anchorPosition.dy - tooltipSize.height - offset;
  }
  // If above would overflow, fallback to below
  if (!preferBelow && (top < offset)) {
    top = anchorPosition.dy + anchorSize.height + offset;
  }
  // Clamp horizontally
  // if (left < margin) {
  //   left = margin;
  // }
  // if (left + tooltipSize.width >= screenSize.width - margin - offset) {
  //   left = screenSize.width - tooltipSize.width - margin - offset;
  // }
  // Clamp vertically
  // if (top < margin) {
  //   top = margin;
  // }
  // if (top + tooltipSize.height >= screenSize.height - margin - offset) {
  //   top = screenSize.height - tooltipSize.height - margin - offset;
  // }
  print("left: $left, top: $top");
  return Offset(left, top);
}
