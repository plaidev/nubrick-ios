//
//  flex.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import YogaKit
import UIKit

class FlexView: AnimatedUIControl {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(block: UIFlexContainerBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        initialize(block: block, context: context, childFlexShrink: nil)
    }
    
    init(block: UIFlexContainerBlock, context: UIBlockContext, childFlexShrink: Int?) {
        super.init(frame: .zero)
        initialize(block: block, context: context, childFlexShrink: childFlexShrink)
    }

    func initialize(block: UIFlexContainerBlock, context: UIBlockContext, childFlexShrink: Int?) {
        let direction = parseDirection(block.data?.direction)
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.display = .flex
            layout.flexDirection = direction
            layout.direction = .LTR
            layout.alignItems = parseAlignItems(block.data?.alignItems)
            layout.justifyContent = parseJustifyContent(block.data?.justifyContent)
            configurePadding(layout: layout, frame: block.data?.frame)
            configureSize(layout: layout, frame: block.data?.frame, parentDirection: context.getParentDireciton())
            configureBorder(view: self, frame: block.data?.frame)
        }

        let gesture = configureOnClickGesture(target: self, action: #selector(onClicked(sender:)), context: context, event: block.data?.onClick)
        let children = block.data?.children?.map {
            uiblockToUIView(data: $0, context: context.instanciateFrom(
                data: nil,
                event: nil,
                parentClickListener: gesture,
                parentDirection: block.data?.direction,
                loading: nil
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
                        layout.marginRight = parseInt((block.data?.frame?.paddingRight ?? 0) +  (block.data?.frame?.paddingLeft ?? 0))

                    }
                    if enableAdjustingYAxisPadding {
                        layout.marginBottom = parseInt((block.data?.frame?.paddingTop ?? 0) +  (block.data?.frame?.paddingBottom ?? 0))
                    }
                }
                
                // when it's wraped by FlexOverflow, set the minimum size not to shrink
                if let childFlexShrink = childFlexShrink {
                    layout.isEnabled = true
                    layout.flexShrink = CGFloat(childFlexShrink)
                    layout.minWidth = layout.width
                    layout.minHeight = layout.height
                }
            }

            self.addSubview(child)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}

class FlexOverflowView: UIScrollView {
    private var flexView: UIView = UIView()
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    init(block: UIFlexContainerBlock, context: UIBlockContext) {
        super.init(frame: .zero)

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
            configureSize(layout: layout, frame: block.data?.frame, parentDirection: context.getParentDireciton())
            configureBorder(view: self, frame: block.data?.frame)
        }

        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        self.isScrollEnabled = (block.data?.overflow == Overflow.SCROLL) ? true : false

        let _ = configureOnClickGesture(target: self, action: #selector(onClicked(sender:)), context: context, event: block.data?.onClick)
        let flexView = FlexView(block: block, context: context, childFlexShrink: 0) // set child's size to shrink 0.
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
        self.contentSize = self.flexView.bounds.size
    }
}
