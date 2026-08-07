//
//  carousel.swift
//  Nubrick
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
        guard pagingArea > 0 else {
            return proposedContentOffset
        }
        let currentOffset = isHorizontal ? collectionView.contentOffset.x : collectionView.contentOffset.y
        let proposedOffset = isHorizontal ? proposedContentOffset.x : proposedContentOffset.y
        let currentPage = currentOffset / pagingArea
        let velocity = isHorizontal ? velocity.x : velocity.y
        let absVelocity = abs(velocity)
        let extraPages = absVelocity > 2.4 ? ceil(absVelocity / 1.5) - 1 : 0.0
        let nextPage = velocity > 0.0
            ? floor(currentPage) + 1 + extraPages
            : ceil(currentPage) - 1 - extraPages

        let page = absVelocity < 0.2 ? round(proposedOffset / pagingArea) : nextPage
        let maximumOffset: CGFloat
        if isHorizontal {
            maximumOffset = max(0, collectionView.contentSize.width - collectionView.bounds.width)
            return CGPoint(
                x: min(max(0, page * pagingArea), maximumOffset), y: proposedContentOffset.y
            )
        } else {
            maximumOffset = max(0, collectionView.contentSize.height - collectionView.bounds.height)
            return CGPoint(
                x: proposedContentOffset.x, y: min(max(0, page * pagingArea), maximumOffset)
            )
        }
    }
}
