//
//  grid.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/31.
//

import Foundation
import UIKit

class GridLayout: UICollectionViewFlowLayout {
    let gap: CGFloat
    init(_ block: UICollectionBlock) {
        self.gap = CGFloat(block.data?.gap ?? 0)
        super.init()

        if block.data?.direction == FlexDirection.COLUMN {
            self.scrollDirection = .vertical
        } else {
            self.scrollDirection = .horizontal
        }
        self.sectionInset = parseFrameDataToUIKitUIEdgeInsets(block.data?.frame)
        self.minimumInteritemSpacing = self.gap
        self.minimumLineSpacing = self.gap
    }

    required init?(coder aDecoder: NSCoder) {
        self.gap = 0
        super.init(coder: aDecoder)
    }
}
