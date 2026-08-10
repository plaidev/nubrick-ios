//
//  collection.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/31.
//

import Combine
import Foundation
import UIKit
internal import YogaKit

class CollectionViewCell: UICollectionViewCell {
    var view: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentView.backgroundColor = .clear
        contentView.isOpaque = false

        contentView.configureLayout { layout in
            layout.isEnabled = true
            layout.justifyContent = .center
            layout.alignItems = .center
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
        contentView.backgroundColor = .clear
        contentView.isOpaque = false

        contentView.configureLayout { layout in
            layout.isEnabled = true
            layout.justifyContent = .center
            layout.alignItems = .center
        }
    }

    func setView(view: UIView) {
        self.view?.removeFromSuperview()
        self.view = view
        self.contentView.addSubview(view)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.contentView.yoga.applyLayout(preservingOrigin: false)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.view?.removeFromSuperview()
        self.view = nil
    }
}

@MainActor
fileprivate func calcCollectionHeight(_ data: UICollectionBlockData?) -> CGFloat {
    let top = data?.frame?.paddingTop ?? 0
    let bottom = data?.frame?.paddingBottom ?? 0
    let itemHeight = data?.itemHeight ?? 1
    let gap = data?.gap ?? 0
    let gridSize = data?.kind == .GRID ? data?.gridSize ?? 1 : 1

    if resolvedFlexDirection(data?.direction) == .COLUMN {
        return CGFloat(itemHeight + top + bottom)
    }
    return CGFloat(gridSize * itemHeight + (gridSize - 1) * gap + top + bottom)
}

@MainActor
fileprivate func calcCollectionWidth(_ data: UICollectionBlockData?) -> CGFloat {
    let left = data?.frame?.paddingLeft ?? 0
    let right = data?.frame?.paddingRight ?? 0
    let itemWidth = data?.itemWidth ?? 1
    let gap = data?.gap ?? 0
    let gridSize = data?.kind == .GRID ? data?.gridSize ?? 1 : 1

    if resolvedFlexDirection(data?.direction) == .COLUMN {
        return CGFloat(gridSize * itemWidth + (gridSize - 1) * gap + left + right)
    }
    return CGFloat(itemWidth + left + right)
}

@MainActor
fileprivate func getCollectionLayout(_ block: UICollectionBlock) -> UICollectionViewFlowLayout {
    switch block.data?.kind {
    case .GRID:
        return GridLayout(block)
    case .CAROUSEL:
        return CarouselLayout(block)
    default:
        return GridLayout(block)
    }
}

@MainActor
fileprivate func configureCollectionSize(
    layout: YGLayout, data: UICollectionBlockData?, parentDirection: FlexDirection?
) {
    // The editor serializes a fill value on the scrolling axis and an explicit
    // cross-axis size. Fall back to the same calculation for older documents.
    // On a matching parent flex axis, fill shares the remaining space with
    // other fill children.
    layout.maxWidth = .init(value: 100, unit: .percent)
    layout.maxHeight = .init(value: 100, unit: .percent)
    if resolvedFlexDirection(data?.direction) == .COLUMN {
        let frameWidth = data?.frame?.width ?? 0
        let width = frameWidth > 0 ? frameWidth : Int(calcCollectionWidth(data))
        layout.width = .init(value: Float(width), unit: .point)
        if parentDirection == .COLUMN {
            layout.height = YGValueAuto
            layout.minHeight = YGValueUndefined
            layout.flexGrow = 1
            layout.flexShrink = 1
            layout.flexBasis = .init(value: 0, unit: .point)
        } else {
            layout.height = .init(value: 100, unit: .percent)
            layout.minHeight = .init(value: 100, unit: .percent)
            layout.flexShrink = 0
        }
    } else {
        let frameHeight = data?.frame?.height ?? 0
        let height = frameHeight > 0 ? frameHeight : Int(calcCollectionHeight(data))
        layout.height = .init(value: Float(height), unit: .point)
        if parentDirection == .ROW {
            layout.width = YGValueAuto
            layout.minWidth = YGValueUndefined
            layout.flexGrow = 1
            layout.flexShrink = 1
            layout.flexBasis = .init(value: 0, unit: .point)
        } else {
            layout.width = .init(value: 100, unit: .percent)
            layout.minWidth = .init(value: 100, unit: .percent)
            layout.flexShrink = 0
        }
    }
}

class CollectionView: AnimatedUIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, BackgroundImageObserver {
    private let block: UICollectionBlock?
    private let context: UIBlockContext
    private var childrenCount: Int = 0
    private var isReferenced: Bool = false
    private var pageControl: UIPageControl? = nil
    private var collectionView: UICollectionView? = nil
    
    // for auto scroll
    private var timer: Timer? = nil
    private var counter: Int = 0
    var cancellables = Set<AnyCancellable>()
    var backgroundImageLoadTask: Task<Void, Never>?
    
    required init?(coder aDecoder: NSCoder) {
        self.block = nil
        self.context = UIBlockContext(UIBlockContextInit())
        self.childrenCount = 0
        self.isReferenced = false
        super.init(coder: aDecoder)
    }
    
    init(block: UICollectionBlock, context: UIBlockContext) {
        self.block = block
        self.context = context
        self.isReferenced = block.data?.reference != nil
        if let reference = block.data?.reference {
            self.childrenCount = Self.referencedItems(reference: reference, variable: context.getVariable()).count
        } else {
            self.childrenCount = block.data?.children?.count ?? 0
        }

        super.init(frame: .zero)

        let layout = getCollectionLayout(block)
        let root = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        self.collectionView = root
        root.backgroundColor = .clear
        root.isOpaque = false
        root.backgroundView = nil
        root.showsVerticalScrollIndicator = false
        root.showsHorizontalScrollIndicator = false
        root.contentInsetAdjustmentBehavior = .never
        root.register(CollectionViewCell.self, forCellWithReuseIdentifier: "CellView")
        root.dataSource = self
        root.delegate = self

        configureOnClickGesture(context: context, uiBlockAction: block.data?.onClick)

        self.configureLayout { layout in
            layout.isEnabled = true
            layout.position = .relative
            // Collections do not support borders in the editor, so ignore any frame border values.
            configureCollectionSize(
                layout: layout, data: block.data, parentDirection: context.getParentDireciton()
            )
        }
        self.addSubview(root)
        
        if block.data?.kind == CollectionKind.CAROUSEL && block.data?.pageControl == true && self.fillsMainAxis {
            let pageControl = UIPageControl(frame: CGRect(x: 0, y: 0, width: 70, height: 30))
            pageControl.numberOfPages = self.childrenCount
            pageControl.currentPage = 0
            pageControl.currentPageIndicatorTintColor = .init(white: 1, alpha: 0.8)
            pageControl.pageIndicatorTintColor = .init(white: 0.4, alpha: 0.3)
            pageControl.isUserInteractionEnabled = false
            if resolvedFlexDirection(block.data?.direction) == .COLUMN {
                pageControl.transform = .init(rotationAngle: .pi / 2)
            }
            self.pageControl = pageControl
            self.addSubview(pageControl)
        }

        makeDisabledStateListener(target: self, context: context, requiredFields: block.data?.onClick?.requiredFields)?.store(in: &cancellables)

        self.bindVariable()
    }

    private var fillsMainAxis: Bool {
        guard self.block?.data?.kind == .CAROUSEL else {
            return false
        }
        if resolvedFlexDirection(self.block?.data?.direction) == .COLUMN {
            return self.block?.data?.fullItemHeight == true
        }
        return self.block?.data?.fullItemWidth == true
    }

    private func bindVariable() {
        if let reference = self.block?.data?.reference {
            self.context.variablePublisher()
                .map { variable in
                    Self.referencedItems(reference: reference, variable: variable).count
                }
                .removeDuplicates()
                .dropFirst()
                .sink { [weak self] childrenCount in
                    guard let self else { return }
                    self.childrenCount = childrenCount

                    self.pageControl?.numberOfPages = self.childrenCount
                    self.setCurrentPage(min(self.getCurrentPage(), max(0, self.childrenCount - 1)))
                    self.collectionView?.reloadData()
                    self.reconcileAutoScrollTimer()
                }
                .store(in: &self.cancellables)
        }

        if let template = self.block?.data?.frame?.backgroundSrc {
            observeBackgroundImage(context: self.context, urlTemplate: template)
        }
    }

    private static func referencedItems(reference: String, variable: Variable?) -> [Any] {
        return variableByPath(path: reference, variable: variable?.value) as? [Any] ?? []
    }

    deinit {
        self.backgroundImageLoadTask?.cancel()
    }

    private func shouldAutoScroll() -> Bool {
        return self.block?.data?.kind == CollectionKind.CAROUSEL
            && self.fillsMainAxis
            && self.block?.data?.autoScroll == true
            && self.childrenCount > 1
    }

    private func startAutoScrollTimerIfNeeded() {
        guard self.timer == nil else { return }
        guard self.shouldAutoScroll() else { return }

        let timeInterval = self.block?.data?.autoScrollInterval ?? 3.0
        guard timeInterval.isFinite, timeInterval > 0 else {
            return
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.automaticScroll()
            }
        }
    }

    private func stopAutoScrollTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }

    private func reconcileAutoScrollTimer() {
        guard self.window != nil else {
            self.stopAutoScrollTimer()
            return
        }

        if self.shouldAutoScroll() {
            self.startAutoScrollTimerIfNeeded()
        } else {
            self.stopAutoScrollTimer()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if self.window == nil {
            self.stopAutoScrollTimer()
        } else {
            self.startAutoScrollTimerIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let root = self.collectionView else {
            return
        }

        // The outer view is owned by the parent flex layout. UICollectionView
        // is deliberately not a Yoga child: UIKit owns its viewport and cell
        // layout once the parent has resolved our bounds. This remains valid
        // when the parent layout engine is replaced.
        let boundsChanged = root.frame != self.bounds
        if boundsChanged {
            root.frame = self.bounds
        }

        let itemSize = self.resolvedItemSize(in: root)
        let flowLayout = root.collectionViewLayout as? UICollectionViewFlowLayout
        let itemSizeChanged = flowLayout?.itemSize != itemSize
        if itemSizeChanged {
            flowLayout?.itemSize = itemSize
        }
        if boundsChanged || itemSizeChanged {
            root.collectionViewLayout.invalidateLayout()
        }

        if let pageControl = self.pageControl {
            let pageControlSize = pageControl.bounds.size
            if (root.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection == .vertical {
                pageControl.center = CGPoint(
                    x: max(pageControlSize.height / 2, self.bounds.width - pageControlSize.height / 2),
                    y: self.bounds.midY
                )
            } else {
                pageControl.frame = CGRect(
                    x: (self.bounds.width - pageControlSize.width) / 2,
                    y: max(0, self.bounds.height - pageControlSize.height),
                    width: pageControlSize.width,
                    height: pageControlSize.height
                )
            }
        }

    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(
            width: calcCollectionWidth(self.block?.data),
            height: calcCollectionHeight(self.block?.data)
        )
    }

    override var intrinsicContentSize: CGSize {
        self.sizeThatFits(.zero)
    }

    private func resolvedItemSize(in collectionView: UICollectionView) -> CGSize {
        let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        let horizontalInsets = (layout?.sectionInset.left ?? 0) + (layout?.sectionInset.right ?? 0)
        let verticalInsets = (layout?.sectionInset.top ?? 0) + (layout?.sectionInset.bottom ?? 0)
        let isVertical = layout?.scrollDirection == .vertical
        var width = CGFloat(self.block?.data?.itemWidth ?? 0)
        var height = CGFloat(self.block?.data?.itemHeight ?? 0)

        if self.fillsMainAxis {
            if isVertical {
                height = max(0, collectionView.bounds.height - verticalInsets)
            } else {
                width = max(0, collectionView.bounds.width - horizontalInsets)
            }
        }
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CellView", for: indexPath)
        if let cell = cell as? CollectionViewCell {
            if self.isReferenced {
                guard let child = self.block?.data?.children?[0] else {
                    return cell
                }
                guard let reference = self.block?.data?.reference else {
                    return cell
                }
                let item = indexPath.item
                let childView = UIViewBlock(
                    data: child,
                    context: self.context.instanciateFrom(
                        UIBlockContextChildInit(
                            variableMapper: { variable in
                                let data = Self.referencedItems(reference: reference, variable: variable)
                                let childData: Any = data.indices.contains(item) ? data[item] : ([:] as [String: Any])
                                return _replaceVariableData(base: variable, data: childData)
                            },
                            parentView: self,
                            parentDirection: resolvedFlexDirection(self.block?.data?.direction),
                            layoutInvalidationRoot: cell
                        )
                    )
                )
                cell.setView(view: childView)
            } else {
                guard let child = self.block?.data?.children?[indexPath.item] else {
                    return cell
                }
                let childView = UIViewBlock(
                    data: child,
                    context: self.context.instanciateFrom(
                        UIBlockContextChildInit(
                            parentView: self,
                            parentDirection: resolvedFlexDirection(self.block?.data?.direction),
                            layoutInvalidationRoot: cell
                        )
                    )
                )
                cell.setView(view: childView)
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.childrenCount
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        self.resolvedItemSize(in: collectionView)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.setCurrentPage(self.getCurrentPage())
    }
        
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.setCurrentPage(self.getCurrentPage())
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.setCurrentPage(self.getCurrentPage())
    }
    
    func getCurrentPage() -> Int {
        guard let pageControl = self.pageControl else {
            return 0
        }
        guard let collectionView = self.collectionView else {
            return 0
        }
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        if let visibleIndexPath = collectionView.indexPathForItem(at: visiblePoint) {
            return visibleIndexPath.row
        }
        return pageControl.currentPage
    }

    private func setCurrentPage(_ page: Int) {
        self.counter = page
        self.pageControl?.currentPage = page
    }
    
    func automaticScroll() {
        guard self.childrenCount > 0 else {
            return
        }
        if self.counter >= self.childrenCount - 1 {
            self.counter = 0
        } else {
            self.counter += 1
        }
        let scrollPosition: UICollectionView.ScrollPosition =
            (self.collectionView?.collectionViewLayout as? UICollectionViewFlowLayout)?
                .scrollDirection == .vertical
                ? .centeredVertically
                : .centeredHorizontally
        self.collectionView?.scrollToItem(
            at: IndexPath(item: self.counter, section: 0), at: scrollPosition, animated: true
        )
    }
}
