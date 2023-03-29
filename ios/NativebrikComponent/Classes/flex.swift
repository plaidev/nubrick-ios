//
//  flex.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import YogaKit
import UIKit

class FlexView: UIView {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    init(block: UIFlexContainerBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        
        let direction = parseDirection(block.data?.direction)
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.display = .flex
            layout.flexDirection = direction
            layout.direction = .LTR
            layout.alignItems = parseAlignItems(block.data?.alignItems)
            layout.justifyContent = parseJustifyContent(block.data?.justifyContent)

            configurePadding(layout: layout, frame: block.data?.frame)
            configureSize(layout: layout, frame: block.data?.frame)
            configureBorder(view: self, frame: block.data?.frame)
        }
        
        let gesture = configureOnClickGesture(target: self, action: #selector(onClicked(sender:)), context: context, event: block.data?.onClick)
        let children = block.data?.children?.map {
            uiblockToUIView(data: $0, context: context.instanciateFrom(
                data: nil,
                event: nil,
                parentClickListener: gesture
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
            }

            self.addSubview(child)
        }
    }
    
    @objc func onClicked(sender: ClickListener) {
        if let onClick = sender.onClick {
            onClick()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
