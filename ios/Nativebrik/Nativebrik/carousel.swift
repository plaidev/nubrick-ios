//
//  carousel.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/31.
//

import Foundation
import UIKit

class CarouselLayout: GridLayout {
    override init(_ block: UICollectionBlock) {
        super.init(block)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override open func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }

    override open func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        guard let collectionView = collectionView else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset)
        }
        let isHorizontal = (self.scrollDirection == .horizontal)
        let pagingArea = (isHorizontal ? self.itemSize.width : self.itemSize.height) + self.gap
        let currentPage = isHorizontal ? collectionView.contentOffset.x / pagingArea : collectionView.contentOffset.y / pagingArea
        let velocity = isHorizontal ? velocity.x : velocity.y
        let absVelocity = abs(velocity)
        let skip = absVelocity > 2.4 ? ceil(absVelocity / 1.5) : 0.0
        let nextPage = velocity >= 0.0 ? ceil(currentPage) + skip : floor(currentPage) - skip

        if absVelocity < 0.2 {
            if isHorizontal {
                return CGPoint(x: round(currentPage) * pagingArea, y: proposedContentOffset.y)
            } else {
                return CGPoint(x: proposedContentOffset.x, y: round(currentPage) * pagingArea)
            }
        }

        if isHorizontal {
            return CGPoint(x: nextPage * pagingArea, y: proposedContentOffset.y)
        } else {
            return CGPoint(x: proposedContentOffset.x, y: nextPage * pagingArea)
        }
    }
}
