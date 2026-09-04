//
//  flex.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Combine
import Foundation
import UIKit
internal import YogaKit

private func minimumSizePreservingUnit(_ size: YGValue) -> YGValue {
    switch size.unit {
    case .point, .percent:
        return size
    default:
        return YGValueUndefined
    }
}

class FlexView: AnimatedUIView, BackgroundImageObserver {
    private var block: UIFlexContainerBlock = UIFlexContainerBlock()
    private var context: UIBlockContext?
    private var isScrollContentView = false
    var cancellables = Set<AnyCancellable>()
    var backgroundImageLoadTask: Task<Void, Never>?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    init(block: UIFlexContainerBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        self.block = block
        self.context = context
        initialize(
            block: block, context: context, childFlexShrink: nil,
            isScrollContentView: false
        )
    }

    init(
        block: UIFlexContainerBlock, context: UIBlockContext, childFlexShrink: Int?,
        isScrollContentView: Bool
    ) {
        super.init(frame: .zero)
        self.block = block
        self.context = context
        initialize(
            block: block, context: context, childFlexShrink: childFlexShrink,
            isScrollContentView: isScrollContentView
        )
    }

    func initialize(
        block: UIFlexContainerBlock, context: UIBlockContext, childFlexShrink: Int?,
        isScrollContentView: Bool
    ) {
        let resolvedDirection = resolvedFlexDirection(block.data?.direction)
        let direction = parseDirection(resolvedDirection)
        // Only the inner content view created by FlexOverflowView skips its
        // own border configuration. HIDDEN uses normal flex measurement and
        // differs from VISIBLE solely by UIKit clipping.
        self.isScrollContentView = isScrollContentView
        self.clipsToBounds = parseOverflow(block.data?.overflow) == .hidden
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.display = .flex
            layout.flexDirection = direction
            layout.direction = .LTR
            layout.alignItems = parseAlignItems(block.data?.alignItems)
            layout.justifyContent = parseJustifyContent(block.data?.justifyContent)
            configurePadding(layout: layout, frame: block.data?.frame)
            if !isScrollContentView {
                configureBorderWidth(layout: layout, frame: block.data?.frame)
            }
            configureSize(
                layout: layout, frame: block.data?.frame,
                parentDirection: context.getParentDireciton())
        }

        configureOnClickGesture(context: context, uiBlockAction: block.data?.onClick)
        let children =
            block.data?.children?.map {
                uiblockToUIView(
                    data: $0,
                    context: context.instanciateFrom(
                        UIBlockContextChildInit(
                            parentView: self,
                            parentDirection: resolvedDirection
                        )
                    ))
            } ?? []
        for (index, child) in children.enumerated() {
            child.configureLayout { (layout) in
                if index != 0 {
                    layout.isEnabled = true

                    if direction == .row {
                        layout.marginLeft = parseInt(block.data?.gap)
                    } else {
                        layout.marginTop = parseInt(block.data?.gap)
                    }
                }

                // when it's wraped by FlexOverflow, set the minimum size not to shrink
                if let childFlexShrink = childFlexShrink {
                    layout.isEnabled = true
                    layout.flexShrink = CGFloat(childFlexShrink)
                    layout.minWidth = minimumSizePreservingUnit(layout.width)
                    layout.minHeight = minimumSizePreservingUnit(layout.height)
                }
            }

            self.addSubview(child)
        }

        if childFlexShrink == nil,
           let context = self.context,
           let template = self.block.data?.frame?.backgroundSrc {
            observeBackgroundImage(context: context, urlTemplate: template)
        }
        
        makeDisabledStateListener(target: self, context: context, requiredFields: block.data?.onClick?.requiredFields)?.store(in: &cancellables)
    }

    deinit {
        self.backgroundImageLoadTask?.cancel()
    }

    func setSafeAreaInsets(_ insets: UIEdgeInsets) {
        let frame = self.block.data?.frame
        self.yoga.paddingTop = YGValue(
            value: Float(CGFloat(frame?.paddingTop ?? 0) + insets.top),
            unit: .point
        )
        self.yoga.paddingLeft = YGValue(
            value: Float(CGFloat(frame?.paddingLeft ?? 0) + insets.left),
            unit: .point
        )
        self.yoga.paddingBottom = YGValue(
            value: Float(CGFloat(frame?.paddingBottom ?? 0) + insets.bottom),
            unit: .point
        )
        self.yoga.paddingRight = YGValue(
            value: Float(CGFloat(frame?.paddingRight ?? 0) + insets.right),
            unit: .point
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !isScrollContentView {
            configureBorder(view: self, frame: self.block.data?.frame)
        }
    }

}

// FlexOverflowView creates a scrollable view and contains FlexView inside as a child.
class FlexOverflowView: UIScrollView, BackgroundImageObserver {
    private var flexView: UIView = UIView()
    private var block: UIFlexContainerBlock = UIFlexContainerBlock()
    private var context: UIBlockContext?
    var cancellables = Set<AnyCancellable>()
    var backgroundImageLoadTask: Task<Void, Never>?

    required init?(coder aDecoder: NSCoder) {
        self.context = nil
        super.init(coder: aDecoder)
    }

    init(block: UIFlexContainerBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        self.block = block
        self.context = context

        self.contentInsetAdjustmentBehavior = .never

        let resolvedDirection = resolvedFlexDirection(block.data?.direction)
        let direction = parseDirection(resolvedDirection)
        let overflow = parseOverflow(block.data?.overflow)
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.display = .flex
            layout.direction = .LTR
            layout.overflow = overflow
            if direction == .column {
                layout.alignItems = .center
                layout.justifyContent = .flexStart
            } else {
                layout.alignItems = .flexStart
                layout.justifyContent = .center
            }
            configureSize(
                layout: layout, frame: block.data?.frame,
                parentDirection: context.getParentDireciton())
            configureBorderWidth(layout: layout, frame: block.data?.frame)
        }
        
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        self.isScrollEnabled = (block.data?.overflow == Overflow.SCROLL) ? true : false
        
        // Create child context with FlexOverflowView's direction as the parent direction
        let childContext = context.instanciateFrom(
            UIBlockContextChildInit(parentDirection: resolvedDirection)
        )
        let flexView = FlexView(
            block: block, context: childContext, childFlexShrink: 0,
            isScrollContentView: true
        )
        flexView.configureLayout { layout in
            if direction == .column {
                layout.maxHeight = YGValueUndefined
                layout.minHeight = YGValueUndefined
                layout.height = YGValueAuto
            } else {
                layout.width = YGValueAuto
                layout.maxWidth = YGValueUndefined
                layout.minWidth = YGValueUndefined
            }
            layout.flexShrink = 0
            layout.flexWrap = .noWrap
        }
        flexView.layer.borderColor = .init(gray: 0, alpha: 0)
        flexView.layer.backgroundColor = .init(gray: 0, alpha: 0)
        self.flexView = flexView
        self.addSubview(flexView)

        if let context = self.context,
           let template = self.block.data?.frame?.backgroundSrc {
            observeBackgroundImage(context: context, urlTemplate: template)
        }
    }

    deinit {
        self.backgroundImageLoadTask?.cancel()
    }

    func setSafeAreaInsets(_ insets: UIEdgeInsets) {
        guard self.contentInset != insets else {
            return
        }
        self.contentInset = insets
        self.verticalScrollIndicatorInsets = insets
        self.horizontalScrollIndicatorInsets = insets
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Re-apply yoga to inner FlexView with flexible dimensions
        // This allows scroll content to grow beyond the scroll view's visible bounds
        // Set min size so inner FlexView fills at least the visible area
        let direction = parseDirection(self.block.data?.direction)
        let borderWidth = CGFloat(max(self.block.data?.frame?.borderWidth ?? 0, 0))
        if direction == .column {
            let visibleHeight = max(
                0,
                self.bounds.height
                    - self.contentInset.top - self.contentInset.bottom
                    - borderWidth * 2
            )
            self.flexView.yoga.minHeight = YGValue(value: Float(visibleHeight), unit: .point)
            self.flexView.yoga.applyLayout(preservingOrigin: true, dimensionFlexibility: .flexibleHeight)
        } else {
            let visibleWidth = max(
                0,
                self.bounds.width
                    - self.contentInset.left - self.contentInset.right
                    - borderWidth * 2
            )
            self.flexView.yoga.minWidth = YGValue(value: Float(visibleWidth), unit: .point)
            self.flexView.yoga.applyLayout(preservingOrigin: true, dimensionFlexibility: .flexibleWidth)
        }

        self.contentSize = CGSize(
            width: max(self.bounds.width, self.flexView.frame.maxX + borderWidth),
            height: max(self.bounds.height, self.flexView.frame.maxY + borderWidth)
        )
        configureBorder(view: self, frame: self.block.data?.frame)
    }

}
