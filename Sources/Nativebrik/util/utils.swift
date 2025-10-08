//
//  utils.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
import YogaKit

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
        return YGValue(value: Float(integer), unit: .point)
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
    if let bg = frame?.background {
        view.layer.backgroundColor = parseColorToCGColor(bg)
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
        if let bc = frame?.borderColor {
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
    if let bc = frame?.borderColor {
        shapeLayer.strokeColor = parseColorToCGColor(bc)
    }
    view.layer.sublayers?.filter { $0.name == "border-layer" }.forEach { $0.removeFromSuperlayer() }
    view.layer.addSublayer(shapeLayer)
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
