//
//  block.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
@_implementationOnly import YogaKit

func childrenToUIViews(data: [UIBlock]?, context: UIBlockContext) -> [UIView] {
    if let children = data {
        return children.map { uiblockToUIView(data: $0, context: context) }
    } else {
        return []
    }
}

func uiblockToUIView(data: UIBlock, context: UIBlockContext, respectSafeArea: Bool? = false) -> UIView {
    switch data {
    case .EUIFlexContainerBlock(let block):
        switch block.data?.overflow {
        case .SCROLL, .HIDDEN:
            return FlexOverflowView(block: block, context: context, respectSafeArea: respectSafeArea ?? false)
        default:
            return FlexView(block: block, context: context, respectSafeArea: respectSafeArea)
        }
    case .EUICollectionBlock(let block):
        return CollectionView(block: block, context: context)
    case .EUICarouselBlock:
        return UIView(frame: .zero)
    case .EUIImageBlock(let image):
        return ImageView(block: image, context: context)
    case .EUITextBlock(let text):
        return TextView(block: text, context: context)
    case .EUITextInputBlock(let input):
        return TextInputView(block: input, context: context)
    case .EUISelectInputBlock(let input):
        if #available(iOS 15.0, *) {
            return SelectInputView(block: input, context: context)
        } else {
            return UIView(frame: .zero)
        }
    case .EUIMultiSelectInputBlock(let block):
        return MultiSelectInputView(block: block, context: context)
    case .EUISwitchInputBlock(let block):
        return SwitchInputView(block: block, context: context)
    default:
        return UIView(frame: .zero)
    }
}

class UIViewBlock: UIView {
    private let root: UIView = UIView()

    init(data: UIBlock, context: UIBlockContext, respectSafeArea: Bool? = false) {
        super.init(frame: .zero)
        let view = uiblockToUIView(data: data, context: context, respectSafeArea: respectSafeArea)

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
    }
}
