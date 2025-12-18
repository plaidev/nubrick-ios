//
//  flex.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
@_implementationOnly import YogaKit

class FlexView: AnimatedUIControl {
    private var block: UIFlexContainerBlock = UIFlexContainerBlock()
    private var context: UIBlockContext?
    private var isOverflowView = false
    private var respectSafeArea = false
    private var hasActivatedConstraints = false

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    init(block: UIFlexContainerBlock, context: UIBlockContext, respectSafeArea: Bool? = false) {
        super.init(frame: .zero)
        self.block = block
        self.context = context
        self.respectSafeArea = respectSafeArea ?? false
        initialize(block: block, context: context, childFlexShrink: nil)
    }

    init(block: UIFlexContainerBlock, context: UIBlockContext, childFlexShrink: Int?) {
        super.init(frame: .zero)
        self.block = block
        initialize(block: block, context: context, childFlexShrink: childFlexShrink)
    }

    func initialize(block: UIFlexContainerBlock, context: UIBlockContext, childFlexShrink: Int?) {
        let direction = parseDirection(block.data?.direction)
        self.isOverflowView =
            block.data?.overflow == Overflow.SCROLL || block.data?.overflow == Overflow.HIDDEN
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.display = .flex
            layout.flexDirection = direction
            layout.direction = .LTR
            layout.alignItems = parseAlignItems(block.data?.alignItems)
            layout.justifyContent = parseJustifyContent(block.data?.justifyContent)
            configurePadding(layout: layout, frame: block.data?.frame)
            configureSize(
                layout: layout, frame: block.data?.frame,
                parentDirection: context.getParentDireciton())
        }

        let gesture = configureOnClickGesture(
            target: self, action: #selector(onClicked(sender:)), context: context,
            event: block.data?.onClick)
        let children =
            block.data?.children?.map {
                uiblockToUIView(
                    data: $0,
                    context: context.instanciateFrom(
                        UIBlockContextChildInit(
                            parentClickListener: gesture,
                            parentDirection: block.data?.direction
                        )
                    ))
            } ?? []
        // somehow, a container.padding won't work when the container size is 100%.
        // so we adjust padding virtually with the margin of the last child.
        let enableAdjustingXAxisPadding = direction == .row && (block.data?.frame?.width == 0)
        let enableAdjustingYAxisPadding = direction == .column && (block.data?.frame?.height == 0)
        let lastChildIndex = children.endIndex
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
                if index == lastChildIndex {
                    if enableAdjustingXAxisPadding {
                        layout.marginRight = parseInt(
                            (block.data?.frame?.paddingRight ?? 0)
                                + (block.data?.frame?.paddingLeft ?? 0))

                    }
                    if enableAdjustingYAxisPadding {
                        layout.marginBottom = parseInt(
                            (block.data?.frame?.paddingTop ?? 0)
                                + (block.data?.frame?.paddingBottom ?? 0))
                    }
                }

                // when it's wraped by FlexOverflow, set the minimum size not to shrink
                if let childFlexShrink = childFlexShrink {
                    layout.isEnabled = true
                    layout.flexShrink = CGFloat(childFlexShrink)
                    layout.minWidth = .init(value: layout.width.value, unit: .point)
                    layout.minHeight = .init(value: layout.height.value, unit: .point)
                }
            }

            self.addSubview(child)
        }

        if childFlexShrink == nil {
            if let bgSrc = block.data?.frame?.backgroundSrc {
                let bgSrc = compile(bgSrc, context.getVariable())
                loadAsyncImageToBackgroundSrc(url: bgSrc, view: self)
            }
        }
        
        let handleDisabled = configureDisabled(target: self, context: context, requiredFields: block.data?.onClick?.requiredFields)
        
        guard let id = block.id, let handleDisabled = handleDisabled else {
            return
        }
        context.addFormValueListener(id, { values in
            handleDisabled(values)
        })
    }
    
    deinit {
        self.context?.removeFormValueListener(self.block.id ?? "")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !isOverflowView {
            configureBorder(view: self, frame: self.block.data?.frame)
        }
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if !self.respectSafeArea { return }
        guard let superview = superview, !hasActivatedConstraints else { return }

        translatesAutoresizingMaskIntoConstraints = false
        topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor).isActive = true
        hasActivatedConstraints = true
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        if !self.respectSafeArea { return }
        if newSuperview == nil { hasActivatedConstraints = false }
    }
}

// FlexOverflowView creates a scrollable view and contains FlexView inside as a child.
class FlexOverflowView: UIScrollView {
    private var flexView: UIView = UIView()
    private var block: UIFlexContainerBlock = UIFlexContainerBlock()
    private var context: UIBlockContext?
    
    required init?(coder aDecoder: NSCoder) {
        self.context = nil
        super.init(coder: aDecoder)
    }

    init(block: UIFlexContainerBlock, context: UIBlockContext, respectSafeArea: Bool) {
        super.init(frame: .zero)
        self.block = block
        self.context = context

        self.contentInsetAdjustmentBehavior = respectSafeArea ? .always : .never

        let direction = parseDirection(block.data?.direction)
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
        }
        
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        self.isScrollEnabled = (block.data?.overflow == Overflow.SCROLL) ? true : false
        
        let _ = configureOnClickGesture(
            target: self, action: #selector(onClicked(sender:)), context: context,
            event: block.data?.onClick)
        // Create child context with FlexOverflowView's direction as the parent direction
        let childContext = context.instanciateFrom(
            UIBlockContextChildInit(parentDirection: block.data?.direction)
        )
        let flexView = FlexView(block: block, context: childContext, childFlexShrink: 0)  // set child's size to shrink 0.
        flexView.configureLayout { layout in
            if direction == .column {
                layout.width = .init(value: 100, unit: .percent)
                layout.maxHeight = YGValueUndefined
                layout.minHeight = YGValueUndefined
                layout.height = YGValueAuto
            } else {
                layout.height = .init(value: 100, unit: .percent)
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

        if let bgSrc = block.data?.frame?.backgroundSrc {
            let bgSrc = compile(bgSrc, context.getVariable())
            loadAsyncImageToBackgroundSrc(url: bgSrc, view: self)
        }
        
        let handleDisabled = configureDisabled(target: self, context: context, requiredFields: block.data?.onClick?.requiredFields)
        
        guard let id = block.id, let handleDisabled = handleDisabled else {
            return
        }
        context.addFormValueListener(id, { values in
            handleDisabled(values)
        })
    }
    
    deinit {
        self.context?.removeFormValueListener(self.block.id ?? "")
    }

    @objc func onClicked(sender: ClickListener) {
        if sender.state == .ended {
            if let onClick = sender.onClick {
                onClick()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Re-apply yoga to inner FlexView with flexible dimensions
        // This allows scroll content to grow beyond the scroll view's visible bounds
        // Set min size so inner FlexView fills at least the visible area
        let direction = parseDirection(self.block.data?.direction)
        if direction == .column {
            self.flexView.yoga.minHeight = YGValue(value: Float(self.bounds.height), unit: .point)
            self.flexView.yoga.applyLayout(preservingOrigin: true, dimensionFlexibility: .flexibleHeight)
        } else {
            self.flexView.yoga.minWidth = YGValue(value: Float(self.bounds.width), unit: .point)
            self.flexView.yoga.applyLayout(preservingOrigin: true, dimensionFlexibility: .flexibleWidth)
        }

        self.contentSize = self.flexView.bounds.size
        configureBorder(view: self, frame: self.block.data?.frame)
    }
}
