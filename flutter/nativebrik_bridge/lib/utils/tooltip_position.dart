import 'package:flutter/widgets.dart';
import 'package:nativebrik_bridge/schema/generated.dart';

Offset calculateTooltipPosition({
  required Offset anchorPosition,
  required Size anchorSize,
  required Size tooltipSize,
  required Size screenSize,
  required UITooltipPlacement placement,
  double offset = 16.0,
  double margin = 16.0,
}) {
  // Initial position variables
  double left = 0.0;
  double top = 0.0;

  // Calculate position based on requested placement
  switch (placement) {
    // TOP placements (tooltip above anchor)
    case UITooltipPlacement.TOP_CENTER:
      left = anchorPosition.dx + (anchorSize.width - tooltipSize.width) / 2;
      top = anchorPosition.dy - tooltipSize.height - offset;
      break;
    case UITooltipPlacement.TOP_START:
      left = anchorPosition.dx;
      top = anchorPosition.dy - tooltipSize.height - offset;
      break;
    case UITooltipPlacement.TOP_END:
      left = anchorPosition.dx + anchorSize.width - tooltipSize.width;
      top = anchorPosition.dy - tooltipSize.height - offset;
      break;

    // BOTTOM placements (tooltip below anchor)
    case UITooltipPlacement.BOTTOM_CENTER:
      left = anchorPosition.dx + (anchorSize.width - tooltipSize.width) / 2;
      top = anchorPosition.dy + anchorSize.height + offset;
      break;
    case UITooltipPlacement.BOTTOM_START:
      left = anchorPosition.dx;
      top = anchorPosition.dy + anchorSize.height + offset;
      break;
    case UITooltipPlacement.BOTTOM_END:
      left = anchorPosition.dx + anchorSize.width - tooltipSize.width;
      top = anchorPosition.dy + anchorSize.height + offset;
      break;

    // LEFT placements (tooltip to the left of anchor)
    case UITooltipPlacement.LEFT_CENTER:
      left = anchorPosition.dx - tooltipSize.width - offset;
      top = anchorPosition.dy + (anchorSize.height - tooltipSize.height) / 2;
      break;
    case UITooltipPlacement.LEFT_START:
      left = anchorPosition.dx - tooltipSize.width - offset;
      top = anchorPosition.dy;
      break;
    case UITooltipPlacement.LEFT_END:
      left = anchorPosition.dx - tooltipSize.width - offset;
      top = anchorPosition.dy + anchorSize.height - tooltipSize.height;
      break;

    // RIGHT placements (tooltip to the right of anchor)
    case UITooltipPlacement.RIGHT_CENTER:
      left = anchorPosition.dx + anchorSize.width + offset;
      top = anchorPosition.dy + (anchorSize.height - tooltipSize.height) / 2;
      break;
    case UITooltipPlacement.RIGHT_START:
      left = anchorPosition.dx + anchorSize.width + offset;
      top = anchorPosition.dy;
      break;
    case UITooltipPlacement.RIGHT_END:
      left = anchorPosition.dx + anchorSize.width + offset;
      top = anchorPosition.dy + anchorSize.height - tooltipSize.height;
      break;

    case UITooltipPlacement.UNKNOWN:
    default:
      // Default to BOTTOM_CENTER if unknown
      left = anchorPosition.dx + (anchorSize.width - tooltipSize.width) / 2;
      top = anchorPosition.dy + anchorSize.height + offset;
      break;
  }

  // Auto adjustment for screen edges
  UITooltipPlacement adjustedPlacement = placement;

  // Check if tooltip would be offscreen and adjust accordingly

  // Off left edge
  if (left < margin) {
    // If we're using LEFT placement, switch to RIGHT
    if (placement == UITooltipPlacement.LEFT_CENTER ||
        placement == UITooltipPlacement.LEFT_START ||
        placement == UITooltipPlacement.LEFT_END) {
      // Recalculate using RIGHT placement
      left = anchorPosition.dx + anchorSize.width + offset;
      adjustedPlacement = placement == UITooltipPlacement.LEFT_CENTER
          ? UITooltipPlacement.RIGHT_CENTER
          : placement == UITooltipPlacement.LEFT_START
              ? UITooltipPlacement.RIGHT_START
              : UITooltipPlacement.RIGHT_END;
    } else {
      left = margin;
    }
  }

  // Off right edge
  if (left + tooltipSize.width > screenSize.width - margin) {
    // If we're using RIGHT placement, switch to LEFT
    if (placement == UITooltipPlacement.RIGHT_CENTER ||
        placement == UITooltipPlacement.RIGHT_START ||
        placement == UITooltipPlacement.RIGHT_END) {
      // Recalculate using LEFT placement
      left = anchorPosition.dx - tooltipSize.width - offset;
      adjustedPlacement = placement == UITooltipPlacement.RIGHT_CENTER
          ? UITooltipPlacement.LEFT_CENTER
          : placement == UITooltipPlacement.RIGHT_START
              ? UITooltipPlacement.LEFT_START
              : UITooltipPlacement.LEFT_END;
    } else {
      left = screenSize.width - tooltipSize.width - margin;
    }
  }

  // Off top edge
  if (top < margin) {
    // If we're using TOP placement, switch to BOTTOM
    if (placement == UITooltipPlacement.TOP_CENTER ||
        placement == UITooltipPlacement.TOP_START ||
        placement == UITooltipPlacement.TOP_END) {
      // Recalculate using BOTTOM placement
      top = anchorPosition.dy + anchorSize.height + offset;
      adjustedPlacement = placement == UITooltipPlacement.TOP_CENTER
          ? UITooltipPlacement.BOTTOM_CENTER
          : placement == UITooltipPlacement.TOP_START
              ? UITooltipPlacement.BOTTOM_START
              : UITooltipPlacement.BOTTOM_END;
    } else {
      top = margin;
    }
  }

  // Off bottom edge
  if (top + tooltipSize.height > screenSize.height - margin) {
    // If we're using BOTTOM placement, switch to TOP
    if (placement == UITooltipPlacement.BOTTOM_CENTER ||
        placement == UITooltipPlacement.BOTTOM_START ||
        placement == UITooltipPlacement.BOTTOM_END) {
      // Recalculate using TOP placement
      top = anchorPosition.dy - tooltipSize.height - offset;
      adjustedPlacement = placement == UITooltipPlacement.BOTTOM_CENTER
          ? UITooltipPlacement.TOP_CENTER
          : placement == UITooltipPlacement.BOTTOM_START
              ? UITooltipPlacement.TOP_START
              : UITooltipPlacement.TOP_END;
    } else {
      top = screenSize.height - tooltipSize.height - margin;
    }
  }

  return Offset(left, top);
}
