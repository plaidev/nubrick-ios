//
//  utils.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
import YogaKit

// Alternative configureBorder that accepts raw dictionary data
func configureBorderWithRawData(view: UIView, frameDict: [String: Any]?) {
    guard let frameDict = frameDict else { return }
    
    // Try new format first (backgroundColorValue)
    if let backgroundColorValue = frameDict["backgroundColorValue"] as? [String: Any] {
        if let colorResult = parseColorValue(backgroundColorValue) {
            switch colorResult {
            case .solid(let color):
                view.layer.backgroundColor = color.cgColor
            case .linearGradient(let gradientLayer):
                // Remove any existing gradient sublayers
                view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
                gradientLayer.frame = view.bounds
                gradientLayer.name = "gradient-layer"
                view.layer.insertSublayer(gradientLayer, at: 0)
            }
        }
    } else if let bgDict = frameDict["background"] as? [String: Any] {
        // Fallback to old format from dictionary
        if let red = bgDict["red"] as? Float,
           let green = bgDict["green"] as? Float,
           let blue = bgDict["blue"] as? Float {
            let alpha = bgDict["alpha"] as? Float ?? 1.0
            let color = UIColor(
                red: CGFloat(clamp(red, min: 0.0, max: 1.0)),
                green: CGFloat(clamp(green, min: 0.0, max: 1.0)),
                blue: CGFloat(clamp(blue, min: 0.0, max: 1.0)),
                alpha: CGFloat(clamp(alpha, min: 0.0, max: 1.0))
            )
            view.layer.backgroundColor = color.cgColor
        }
    }
    
    // Handle the rest of border configuration
    let width = view.bounds.width
    let height = view.bounds.height
    
    let borderWidth = frameDict["borderWidth"] as? Int ?? 0
    let borderRadius = frameDict["borderRadius"] as? Int ?? 0
    let borderTopLeftRadius = frameDict["borderTopLeftRadius"] as? Int
    let borderTopRightRadius = frameDict["borderTopRightRadius"] as? Int
    let borderBottomLeftRadius = frameDict["borderBottomLeftRadius"] as? Int
    let borderBottomRightRadius = frameDict["borderBottomRightRadius"] as? Int
    
    let isSingleRadius =
        (borderTopLeftRadius == borderTopRightRadius) &&
        (borderTopLeftRadius == borderBottomLeftRadius) &&
        (borderTopLeftRadius == borderBottomRightRadius)
    
    if isSingleRadius {
        // if radius is not set or single value
        view.layer.borderWidth = CGFloat(borderWidth)
        if let bc = frameDict["borderColor"] as? [String: Any] {
            if let red = bc["red"] as? Float,
               let green = bc["green"] as? Float,
               let blue = bc["blue"] as? Float {
                let alpha = bc["alpha"] as? Float ?? 1.0
                let color = UIColor(
                    red: CGFloat(clamp(red, min: 0.0, max: 1.0)),
                    green: CGFloat(clamp(green, min: 0.0, max: 1.0)),
                    blue: CGFloat(clamp(blue, min: 0.0, max: 1.0)),
                    alpha: CGFloat(clamp(alpha, min: 0.0, max: 1.0))
                )
                view.layer.borderColor = color.cgColor
            }
        }
        view.layer.cornerRadius = CGFloat(
            normalizeSingleRadius(
                radius: CGFloat(borderRadius), width: width, height: height))
        return
    }
    
    // Complex border radius handling would go here...
}

func presentOnTop(window: UIWindow?, modal: UIViewController) {
    guard let root = window?.rootViewController else {
        return
    }
    guard let presented = root.presentedViewController else {
        root.present(modal, animated: true)
        return
    }
    presented.present(modal, animated: true)
}

func parseInt(_ data: Int?) -> YGValue {
    if let integer = data {
        return YGValue(value: Float(integer), unit: .point)
    } else {
        return YGValueZero
    }
}

func parseIntForFlex(_ data: Int?) -> YGValue? {
    if let integer = data {
        return YGValue(CGFloat(integer))
    } else {
        return YGValueUndefined
    }
}

func parseDirection(_ data: FlexDirection?) -> YGFlexDirection {
    switch data {
    case .COLUMN:
        return .column
    default:
        return .row
    }
}

func parseOverflow(_ data: Overflow?) -> YGOverflow {
    switch data {
    case .HIDDEN:
        return .hidden
    case .SCROLL:
        return .scroll
    case .VISIBLE:
        return .visible
    default:
        return .visible
    }
}

func parseAlignItems(_ data: AlignItems?) -> YGAlign {
    switch data {
    case .CENTER:
        return .center
    case .END:
        return .flexEnd
    case .START:
        return .flexStart
    default:
        return .center
    }
}

func parseJustifyContent(_ data: JustifyContent?) -> YGJustify {
    switch data {
    case .CENTER:
        return .center
    case .START:
        return .flexStart
    case .END:
        return .flexEnd
    case .SPACE_BETWEEN:
        return .spaceBetween
    default:
        return .center
    }
}

func parseColor(_ data: Color?) -> UIColor {
    if let color = data {
        return UIColor.init(
            red: CGFloat(color.red ?? 0), green: CGFloat(color.green ?? 0),
            blue: CGFloat(color.blue ?? 0), alpha: CGFloat(color.alpha ?? 0))
    } else {
        return UIColor.black
    }
}

enum ColorValueResult {
    case solid(UIColor)
    case linearGradient(CAGradientLayer)
}

// Old GradientDirection enum for raw dictionary parsing
enum OldGradientDirection: String {
    case toTop = "to-top"
    case toTopRight = "to-top-right"
    case toRight = "to-right"
    case toBottomRight = "to-bottom-right"
    case toBottom = "to-bottom"
    case toBottomLeft = "to-bottom-left"
    case toLeft = "to-left"
    case toTopLeft = "to-top-left"
    
    var startPoint: CGPoint {
        switch self {
        case .toTop: return CGPoint(x: 0.5, y: 1.0)
        case .toTopRight: return CGPoint(x: 0.0, y: 1.0)
        case .toRight: return CGPoint(x: 0.0, y: 0.5)
        case .toBottomRight: return CGPoint(x: 0.0, y: 0.0)
        case .toBottom: return CGPoint(x: 0.5, y: 0.0)
        case .toBottomLeft: return CGPoint(x: 1.0, y: 0.0)
        case .toLeft: return CGPoint(x: 1.0, y: 0.5)
        case .toTopLeft: return CGPoint(x: 1.0, y: 1.0)
        }
    }
    
    var endPoint: CGPoint {
        switch self {
        case .toTop: return CGPoint(x: 0.5, y: 0.0)
        case .toTopRight: return CGPoint(x: 1.0, y: 0.0)
        case .toRight: return CGPoint(x: 1.0, y: 0.5)
        case .toBottomRight: return CGPoint(x: 1.0, y: 1.0)
        case .toBottom: return CGPoint(x: 0.5, y: 1.0)
        case .toBottomLeft: return CGPoint(x: 0.0, y: 1.0)
        case .toLeft: return CGPoint(x: 0.0, y: 0.5)
        case .toTopLeft: return CGPoint(x: 0.0, y: 0.0)
        }
    }
}

func parseColorValue(_ data: [String: Any]?) -> ColorValueResult? {
    guard let data = data else { return nil }
    
    // Check for new format with __typename
    if let typename = data["__typename"] as? String {
        switch typename {
        case "SolidColor":
            if let colorData = data["color"] as? [String: Any] {
                let color = parseSolidColorFromDict(colorData)
                return .solid(color)
            }
        case "LinearGradient":
            if let gradientLayer = parseLinearGradient(data) {
                return .linearGradient(gradientLayer)
            }
        default:
            break
        }
    }
    
    // Fallback to old format (direct color values)
    if let red = data["red"] as? Float,
       let green = data["green"] as? Float,
       let blue = data["blue"] as? Float {
        let alpha = data["alpha"] as? Float ?? 1.0
        let color = UIColor(
            red: CGFloat(clamp(red, min: 0.0, max: 1.0)),
            green: CGFloat(clamp(green, min: 0.0, max: 1.0)),
            blue: CGFloat(clamp(blue, min: 0.0, max: 1.0)),
            alpha: CGFloat(clamp(alpha, min: 0.0, max: 1.0))
        )
        return .solid(color)
    }
    
    return nil
}

func parseSolidColorFromDict(_ data: [String: Any]) -> UIColor {
    let red = data["red"] as? Float ?? 0.0
    let green = data["green"] as? Float ?? 0.0
    let blue = data["blue"] as? Float ?? 0.0
    let alpha = data["alpha"] as? Float ?? 1.0
    
    return UIColor(
        red: CGFloat(clamp(red, min: 0.0, max: 1.0)),
        green: CGFloat(clamp(green, min: 0.0, max: 1.0)),
        blue: CGFloat(clamp(blue, min: 0.0, max: 1.0)),
        alpha: CGFloat(clamp(alpha, min: 0.0, max: 1.0))
    )
}

func parseLinearGradient(_ data: [String: Any]) -> CAGradientLayer? {
    let gradientLayer = CAGradientLayer()
    
    // Parse direction
    if let directionString = data["direction"] as? String,
       let direction = OldGradientDirection(rawValue: directionString) {
        gradientLayer.startPoint = direction.startPoint
        gradientLayer.endPoint = direction.endPoint
    } else {
        // Default to top-to-bottom
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    }
    
    // Parse stops
    if let stops = data["stops"] as? [[String: Any]] {
        var colors: [CGColor] = []
        var locations: [NSNumber] = []
        
        for stop in stops {
            if let colorData = stop["color"] as? [String: Any] {
                let color = parseSolidColorFromDict(colorData)
                colors.append(color.cgColor)
                
                if let position = stop["position"] as? Float {
                    locations.append(NSNumber(value: position))
                } else {
                    // If no position specified, let Core Animation distribute evenly
                    locations.append(NSNumber(value: Float(locations.count) / Float(max(stops.count - 1, 1))))
                }
            }
        }
        
        if !colors.isEmpty {
            gradientLayer.colors = colors
            gradientLayer.locations = locations.count == colors.count ? locations : nil
        }
    }
    
    return gradientLayer
}

// Convert generated ColorValue to ColorValueResult
func parseColorValueFromGenerated(_ colorValue: ColorValue?) -> ColorValueResult? {
    guard let colorValue = colorValue else {
        return nil
    }
    
    switch colorValue {
    case .ESolidColor(let solidColor):
        if let color = solidColor.color {
            return .solid(parseColor(color))
        }
        return nil
    case .ELinearGradient(let linearGradient):
        return parseLinearGradientFromGenerated(linearGradient)
    case .unknown:
        return nil
    }
}

// Convert generated LinearGradient to CAGradientLayer
func parseLinearGradientFromGenerated(_ gradient: LinearGradient) -> ColorValueResult? {
    let gradientLayer = CAGradientLayer()
    
    // Parse direction
    if let direction = gradient.direction {
        switch direction {
        case .TO_TOP:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        case .TO_TOP_RIGHT:
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
        case .TO_RIGHT:
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        case .TO_BOTTOM_RIGHT:
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        case .TO_BOTTOM:
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        case .TO_BOTTOM_LEFT:
            gradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        case .TO_LEFT:
            gradientLayer.startPoint = CGPoint(x: 1.0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 0.0, y: 0.5)
        case .TO_TOP_LEFT:
            gradientLayer.startPoint = CGPoint(x: 1.0, y: 1.0)
            gradientLayer.endPoint = CGPoint(x: 0.0, y: 0.0)
        case .unknown:
            // Default to top-to-bottom
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        }
    } else {
        // Default to top-to-bottom
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    }
    
    // Parse stops
    if let stops = gradient.stops {
        var colors: [CGColor] = []
        var locations: [NSNumber] = []
        
        for stop in stops {
            if let color = stop.color {
                colors.append(parseColorToCGColor(color))
                
                if let position = stop.position {
                    locations.append(NSNumber(value: position))
                }
            }
        }
        
        if !colors.isEmpty {
            gradientLayer.colors = colors
            gradientLayer.locations = locations.count == colors.count ? locations : nil
        }
    }
    
    return .linearGradient(gradientLayer)
}

func parseColorToCGColor(_ data: Color?) -> CGColor {
    guard
        let color = data,
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    else { return CGColor(gray: 0, alpha: 0) }

    let components: [CGFloat] = [
        CGFloat(clamp(color.red ?? 0.0, min: 0.0, max: 1.0)),
        CGFloat(clamp(color.green ?? 0.0, min: 0.0, max: 1.0)),
        CGFloat(clamp(color.blue ?? 0.0, min: 0.0, max: 1.0)),
        CGFloat(clamp(color.alpha ?? 0.0, min: 0.0, max: 1.0)),
    ]

    return CGColor(colorSpace: colorSpace, components: components)
        ?? CGColor(gray: 0, alpha: 0)
}

func parseFontWeight(_ data: FontWeight?) -> UIFont.Weight {
    switch data {
    case .some(data):
        switch data {
        case .ULTRA_LIGHT:
            return .ultraLight
        case .THIN:
            return .thin
        case .LIGHT:
            return .light
        case .REGULAR:
            return .regular
        case .MEDIUM:
            return .medium
        case .SEMI_BOLD:
            return .semibold
        case .BOLD:
            return .bold
        case .HEAVY:
            return .heavy
        case .BLACK:
            return .black
        default:
            return .regular
        }
    default:
        return .regular
    }
}

func parseFontDesign(_ data: FontDesign?) -> UIFontDescriptor.SystemDesign {
    switch data {
    case .MONOSPACE:
        return .monospaced
    case .ROUNDED:
        return .rounded
    case .SERIF:
        return .serif
    default:
        return .default
    }
}

func parseTextBlockDataToUIFont(_ size: Int?, _ weight: FontWeight?, _ design: FontDesign?)
    -> UIFont
{
    let size = CGFloat(size ?? 16)
    let systemFont = UIFont.systemFont(ofSize: size, weight: parseFontWeight(weight))
    let font: UIFont
    if let descriptor = systemFont.fontDescriptor.withDesign(parseFontDesign(design)) {
        font = UIFont(descriptor: descriptor, size: size)
    } else {
        font = systemFont
    }
    return font
}

func parseFrameDataToUIKitUIEdgeInsets(_ data: FrameData?) -> UIEdgeInsets {
    return UIEdgeInsets(
        top: CGFloat(data?.paddingTop ?? 0),
        left: CGFloat(data?.paddingLeft ?? 0),
        bottom: CGFloat(data?.paddingBottom ?? 0),
        right: CGFloat(data?.paddingRight ?? 0)
    )
}

func parseModalPresentationStyle(_ data: ModalPresentationStyle?) -> UIModalPresentationStyle {
    switch data {
    case .DEPENDS_ON_CONTEXT_OR_PAGE_SHEET:
        return .pageSheet
    default:
        return .overFullScreen
    }
}

@available(iOS 15.0, *)
func parseModalScreenSize(_ data: ModalScreenSize?) -> [UISheetPresentationController.Detent] {
    switch data {
    case .MEDIUM:
        return [.medium()]
    case .LARGE:
        return [.large()]
    default:
        return [.medium(), .large()]
    }
}

func parseTextAlign(_ data: TextAlign?) -> NSTextAlignment {
    switch data {
    case .LEFT:
        return .left
    case .CENTER:
        return .center
    case .RIGHT:
        return .right
    default:
        return .natural
    }
}

func parseTextAlignToHorizontalAlignment(_ data: TextAlign?)
    -> UIControl.ContentHorizontalAlignment
{
    switch data {
    case .LEFT:
        return .left
    case .CENTER:
        return .center
    case .RIGHT:
        return .right
    default:
        return .left
    }
}

func parserKeyboardType(_ data: UITextInputKeyboardType?) -> UIKeyboardType {
    switch data {
    case .ALPHABET:
        return .alphabet
    case .ASCII:
        return .asciiCapable
    case .DECIMAL:
        return .decimalPad
    case .NUMBER:
        return .numberPad
    case .URI:
        return .URL
    case .EMAIL:
        return .emailAddress
    default:
        return .default
    }
}

func parseImageContentMode(_ data: ImageContentMode?) -> UIView.ContentMode {
    switch data {
    case .FIT:
        return .scaleAspectFit
    default:
        return .scaleAspectFill
    }
}

struct ImageFallback {
    let blurhash: String
    let width: Int
    let height: Int
}
func parseImageFallbackToBlurhash(_ src: String) -> ImageFallback {
    guard let url = URL(string: src) else {
        return ImageFallback(blurhash: "", width: 0, height: 0)
    }

    let width = url.value(for: "w")
    let height = url.value(for: "h")
    let blurhash = url.value(for: "b")

    if let width = width, let height = height, let blurhash = blurhash {
        return ImageFallback(blurhash: blurhash, width: Int(width) ?? 0, height: Int(height) ?? 0)
    } else {
        return ImageFallback(blurhash: "", width: 0, height: 0)
    }
}

extension URL {
    func value(for parameter: String) -> String? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }

        return components.queryItems?.first(where: { $0.name == parameter })?.value
    }
}

func configurePadding(layout: YGLayout, frame: FrameData?) {
    layout.paddingTop = parseInt(frame?.paddingTop)
    layout.paddingLeft = parseInt(frame?.paddingLeft)
    layout.paddingRight = parseInt(frame?.paddingRight)
    layout.paddingBottom = parseInt(frame?.paddingBottom)
}

func configureSize(layout: YGLayout, frame: FrameData?, parentDirection: FlexDirection?) {
    if let height = frame?.height {
        if height == 0 {  // fill
            layout.height = .init(value: 100.0, unit: .percent)
            layout.minHeight = .init(value: 100.0, unit: .percent)
        } else {  // static
            layout.height = YGValue(value: Float(height), unit: .point)
        }
    }
    if let width = frame?.width {
        if width == 0 {
            layout.width = .init(value: 100.0, unit: .percent)
            layout.minWidth = .init(value: 100.0, unit: .percent)
        } else {
            layout.width = YGValue(value: Float(width), unit: .point)
        }
    }

    layout.maxWidth = .init(value: 100, unit: .percent)
    layout.maxHeight = .init(value: 100, unit: .percent)
    layout.flexShrink = 0.0

    if parentDirection == FlexDirection.ROW && frame?.width == 0 {
        layout.width = YGValueAuto
        layout.minWidth = YGValueUndefined
        layout.flexGrow = 1.0
        layout.flexShrink = 1.0
    }

    // content fit
    if parentDirection == FlexDirection.COLUMN && frame?.height == 0 {
        layout.height = YGValueAuto
        layout.minHeight = YGValueUndefined
        layout.flexGrow = 1.0
        layout.flexShrink = 1.0
    }
}

private struct BorderRadius {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomRight: CGFloat
    let bottomLeft: CGFloat
}

private func normalizeRadius(radius: BorderRadius, width: CGFloat, height: CGFloat) -> BorderRadius
{
    let (topLeft, topRight, bottomRight, bottomLeft) = (
        radius.topLeft, radius.topRight, radius.bottomRight, radius.bottomLeft
    )
    var f = 1.0

    for (l, s) in [
        (width, topLeft + topRight),
        (height, topLeft + bottomLeft),
        (height, topRight + bottomRight),
        (width, bottomLeft + bottomRight),
    ] {
        if s > 0 && s > l {
            f = min(f, l / s)
        }
    }

    return BorderRadius(
        topLeft: topLeft * f,
        topRight: topRight * f,
        bottomRight: bottomRight * f,
        bottomLeft: bottomLeft * f
    )
}

private func normalizeSingleRadius(radius: CGFloat, width: CGFloat, height: CGFloat) -> CGFloat {
    if radius <= 0 {
        return 0
    }
    let l = width > height ? height : width
    return radius * min(1, l / radius / 2)
}

// NOTE: should be called in viewDidLayoutSubviews to wait until view.bounds are set
func configureBorder(view: UIView, frame: FrameData?) {
    // Debug logging
    
    // Handle background using new ColorValue format if available
    if let backgroundValue = frame?.backgroundValue {
        if let colorResult = parseColorValueFromGenerated(backgroundValue) {
            switch colorResult {
            case .solid(let color):
                view.layer.backgroundColor = color.cgColor
                view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
            case .linearGradient(let gradientLayer):
                print("DEBUG: Applying gradient layer with bounds: \(view.bounds)")
                view.layer.backgroundColor = UIColor.clear.cgColor
                view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
                gradientLayer.frame = view.bounds
                gradientLayer.name = "gradient-layer"
                view.layer.insertSublayer(gradientLayer, at: 0)
            }
        }
    } else if let bg = frame?.background {
        view.layer.backgroundColor = parseColorToCGColor(bg)
        view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
    }

    let width = view.bounds.width
    let height = view.bounds.height

    let isSingleRadius =
        (frame?.borderTopLeftRadius == frame?.borderTopRightRadius)
        && (frame?.borderTopLeftRadius == frame?.borderBottomLeftRadius)
        && (frame?.borderTopLeftRadius == frame?.borderBottomRightRadius)

    if isSingleRadius {
        // if radius is not set or single value
        view.layer.borderWidth = CGFloat(frame?.borderWidth ?? 0)
        
        if let borderColorValue = frame?.borderColorValue {
            if let colorResult = parseColorValueFromGenerated(borderColorValue) {
                switch colorResult {
                case .solid(let color):
                    view.layer.borderColor = color.cgColor
                case .linearGradient(_):
                    break
                }
            }
        } else if let bc = frame?.borderColor {
            view.layer.borderColor = parseColorToCGColor(bc)
        }
        view.layer.cornerRadius = CGFloat(
            normalizeSingleRadius(
                radius: CGFloat(frame?.borderRadius ?? 0), width: width, height: height))
        return
    }

    let radius = normalizeRadius(
        radius: BorderRadius(
            topLeft: CGFloat(frame?.borderTopLeftRadius ?? 0),
            topRight: CGFloat(frame?.borderTopRightRadius ?? 0),
            bottomRight: CGFloat(frame?.borderBottomRightRadius ?? 0),
            bottomLeft: CGFloat(frame?.borderBottomLeftRadius ?? 0)
        ),
        width: width,
        height: height
    )
    let (topLeftRadius, topRightRadius, bottomRightRadius, bottomLeftRadius) = (
        radius.topLeft, radius.topRight, radius.bottomRight, radius.bottomLeft
    )

    let topLeft = CGPoint(x: 0, y: 0)
    let topRight = CGPoint(x: width, y: 0)
    let bottomRight = CGPoint(x: width, y: height)
    let bottomLeft = CGPoint(x: 0, y: height)

    // draw rect path with corner radius
    let path = UIBezierPath()
    path.move(to: CGPoint(x: topLeft.x + topLeftRadius, y: topLeft.y))
    path.addLine(to: CGPoint(x: topRight.x - topRightRadius, y: topRight.y))
    path.addArc(
        withCenter: CGPoint(x: topRight.x - topRightRadius, y: topRight.y + topRightRadius),
        radius: topRightRadius,
        startAngle: -.pi / 2,
        endAngle: 0,
        clockwise: true)
    path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y - bottomRightRadius))
    path.addArc(
        withCenter: CGPoint(
            x: bottomRight.x - bottomRightRadius, y: bottomRight.y - bottomRightRadius),
        radius: bottomRightRadius,
        startAngle: 0,
        endAngle: .pi / 2,
        clockwise: true)
    path.addLine(to: CGPoint(x: bottomLeft.x + bottomLeftRadius, y: bottomLeft.y))
    path.addArc(
        withCenter: CGPoint(x: bottomLeft.x + bottomLeftRadius, y: bottomLeft.y - bottomLeftRadius),
        radius: bottomLeftRadius,
        startAngle: .pi / 2,
        endAngle: .pi,
        clockwise: true)
    path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y + topLeftRadius))
    path.addArc(
        withCenter: CGPoint(x: topLeft.x + topLeftRadius, y: topLeft.y + topLeftRadius),
        radius: topLeftRadius,
        startAngle: .pi,
        endAngle: -.pi / 2,
        clockwise: true)
    path.close()

    // clip corner
    let maskLayer = CAShapeLayer()
    maskLayer.frame = view.bounds
    maskLayer.path = path.cgPath
    maskLayer.fillColor = UIColor.white.cgColor
    view.layer.mask = maskLayer

    // set border
    let shapeLayer = CAShapeLayer()
    shapeLayer.frame = view.bounds
    shapeLayer.path = path.cgPath
    shapeLayer.lineWidth = CGFloat(frame?.borderWidth ?? 0)
    shapeLayer.fillColor = UIColor.clear.cgColor
    shapeLayer.name = "border-layer"
    if let borderColorValue = frame?.borderColorValue {
        if let colorResult = parseColorValueFromGenerated(borderColorValue) {
            switch colorResult {
            case .solid(let color):
                shapeLayer.strokeColor = color.cgColor
            case .linearGradient(let gradientLayer):
                let gradientBorderLayer = CAGradientLayer()
                gradientBorderLayer.frame = view.bounds
                gradientBorderLayer.colors = gradientLayer.colors
                gradientBorderLayer.locations = gradientLayer.locations
                gradientBorderLayer.startPoint = gradientLayer.startPoint
                gradientBorderLayer.endPoint = gradientLayer.endPoint
                
                let borderMask = CAShapeLayer()
                borderMask.path = path.cgPath
                borderMask.fillColor = UIColor.clear.cgColor
                borderMask.strokeColor = UIColor.black.cgColor
                borderMask.lineWidth = CGFloat(frame?.borderWidth ?? 0)
                borderMask.frame = view.bounds
                
                gradientBorderLayer.mask = borderMask
                gradientBorderLayer.name = "gradient-border-layer"
                view.layer.sublayers?.filter { $0.name == "gradient-border-layer" }.forEach { $0.removeFromSuperlayer() }
                view.layer.addSublayer(gradientBorderLayer)
                
                // Don't add the regular shape layer if we're using gradient
                view.layer.sublayers?.filter { $0.name == "border-layer" }.forEach { $0.removeFromSuperlayer() }
                return
            }
        }
    } else if let bc = frame?.borderColor {
        // Fallback to old format
        shapeLayer.strokeColor = parseColorToCGColor(bc)
    }
    
    view.layer.sublayers?.filter { $0.name == "border-layer" || $0.name == "gradient-border-layer" }.forEach { $0.removeFromSuperlayer() }
    view.layer.addSublayer(shapeLayer)
}

func configureBackgroundWithFallback(view: UIView, frame: FrameData?) {
    if let backgroundValue = frame?.backgroundValue {
        if let colorResult = parseColorValueFromGenerated(backgroundValue) {
            switch colorResult {
            case .solid(let color):
                view.backgroundColor = color
                view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
            case .linearGradient(let gradientLayer):
                view.backgroundColor = .clear
                view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
                gradientLayer.frame = view.bounds
                gradientLayer.name = "gradient-layer"
                view.layer.insertSublayer(gradientLayer, at: 0)
            }
            return
        }
    }
    
    if let bg = frame?.background {
        view.backgroundColor = parseColor(bg)
        // Remove any gradient layers if they exist
        view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
    }
}

// Alternative version that accepts raw dictionary data for new format support
func configureBackgroundWithFallbackRawData(view: UIView, frameDict: [String: Any]?) {
    guard let frameDict = frameDict else { return }
    
    // Try new format first (backgroundColorValue)
    if let backgroundColorValue = frameDict["backgroundColorValue"] as? [String: Any] {
        if let colorResult = parseColorValue(backgroundColorValue) {
            switch colorResult {
            case .solid(let color):
                view.backgroundColor = color
                // Remove any gradient layers if they exist
                view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
            case .linearGradient(let gradientLayer):
                // Clear background color
                view.backgroundColor = .clear
                // Remove any existing gradient sublayers
                view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
                gradientLayer.frame = view.bounds
                gradientLayer.name = "gradient-layer"
                view.layer.insertSublayer(gradientLayer, at: 0)
            }
            return
        }
    }
    
    // Fallback to old format
    if let bgDict = frameDict["background"] as? [String: Any] {
        if let red = bgDict["red"] as? Float,
           let green = bgDict["green"] as? Float,
           let blue = bgDict["blue"] as? Float {
            let alpha = bgDict["alpha"] as? Float ?? 1.0
            let color = UIColor(
                red: CGFloat(clamp(red, min: 0.0, max: 1.0)),
                green: CGFloat(clamp(green, min: 0.0, max: 1.0)),
                blue: CGFloat(clamp(blue, min: 0.0, max: 1.0)),
                alpha: CGFloat(clamp(alpha, min: 0.0, max: 1.0))
            )
            view.backgroundColor = color
            // Remove any gradient layers if they exist
            view.layer.sublayers?.filter { $0.name == "gradient-layer" }.forEach { $0.removeFromSuperlayer() }
        }
    }
}

func configureShadow(view: UIView, shadow: BoxShadow?) {
    if let shadow = shadow {
        view.layer.shadowColor = parseColorToCGColor(shadow.color)
        view.layer.shadowOffset = CGSize(width: shadow.offsetX ?? 0, height: shadow.offsetY ?? 0)
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = CGFloat(shadow.radius ?? 0)
        view.layer.shouldRasterize = true
        view.layer.shadowPath = UIBezierPath(roundedRect: view.frame, cornerRadius: 8).cgPath
    }
}

func configureSkelton(view: UIView, showSkelton: Bool) {
    if showSkelton == false {
        return
    }
    let gray = 0.5
    let alpha = 0.3
    view.layer.backgroundColor = .init(gray: gray, alpha: alpha)
    UIView.animateKeyframes(
        withDuration: 1.5, delay: 0.0,
        options: [.repeat, .calculationModeCubicPaced, .allowUserInteraction]
    ) {
        UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0) {
            view.layer.backgroundColor = .init(gray: gray, alpha: alpha)
        }
        UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
            view.layer.backgroundColor = .init(gray: gray, alpha: alpha * 0.7)
        }
        UIView.addKeyframe(withRelativeStartTime: 1.0, relativeDuration: 0.5) {
            view.layer.backgroundColor = .init(gray: gray, alpha: alpha)
        }
    }
}

func configureSkeltonText(view: UILabel, showSkelton: Bool) {
    if showSkelton == false {
        return
    }
    let text = view.text ?? ""
    if text.lengthOfBytes(using: .utf8) < 2 {
        view.text = "TRANSPARENT"
    }

    view.textColor = .init(white: 0, alpha: 0)
}

func clamp<V: Comparable>(_ value: V, min minValue: V, max maxValue: V) -> V {
    return max(minValue, min(value, maxValue))
}
