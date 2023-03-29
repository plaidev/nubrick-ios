//
//  block.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
import YogaKit

func childrenToUIViews(data: [UIBlock]?, context: UIBlockContext) -> [UIView] {
    if let children = data {
        return children.map { uiblockToUIView(data: $0, context: context) }
    } else {
        return []
    }
}

func uiblockToUIView(data: UIBlock, context: UIBlockContext) -> UIView {
    switch data {
    case .EUIFlexContainerBlock(let block):
        return FlexView(block: block, context: context)
    case .EUICollectionBlock:
        return UIView(frame: .zero)
    case .EUICarouselBlock:
        return UIView(frame: .zero)
    case .EUIImageBlock(let image):
        return ImageView(block: image, context: context)
    case .EUITextBlock(let text):
        return TextView(block: text, context: context)
    default:
        return UIView(frame: .zero)
    }
}

class UIViewBlock: UIView {
    private let root: UIView = UIView()

    init(data: UIBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        let view = uiblockToUIView(data: data, context: context)
        
        self.configureLayout { (layout) in
            layout.isEnabled = true
            layout.display = .flex
            layout.flexDirection = .row
            layout.justifyContent = .center
            layout.alignItems = .center
        }
        
        self.addSubview(view)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.yoga.applyLayout(preservingOrigin: false)
    }
}
