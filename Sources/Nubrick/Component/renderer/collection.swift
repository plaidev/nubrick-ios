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
    var gridSize = 1

    if (data?.kind == CollectionKind.GRID) {
        gridSize = data?.gridSize ?? 1
    }

    return CGFloat(gridSize * itemHeight + (gridSize - 1) * gap + top + bottom)
}

@MainActor
fileprivate func calcCollectionWidth(_ data: UICollectionBlockData?) -> CGFloat {
    let left = data?.frame?.paddingLeft ?? 0
    let right = data?.frame?.paddingRight ?? 0
    let itemWidth = data?.itemWidth ?? 1
    let gap = data?.gap ?? 0
    var gridSize = 1

    if (data?.kind == CollectionKind.GRID) {
        gridSize = data?.gridSize ?? 1
    }

    return CGFloat(gridSize * itemWidth + (gridSize - 1) * gap + left + right)
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

class CollectionView: AnimatedUIControl, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, BackgroundImageObserver {
    private let block: UICollectionBlock?
    private let context: UIBlockContext
    private var childrenCount: Int = 0
    private var isReferenced: Bool = false
    private var gesture: ClickListener? = nil
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
            frame: CGRect(
                x: 0,
                y: 0,
                width: calcCollectionWidth(block.data),
                height: calcCollectionHeight(block.data)
            ),
            collectionViewLayout: layout
        )
        self.collectionView = root
        root.backgroundColor = .clear
        root.isOpaque = false
        root.backgroundView = nil
        root.showsVerticalScrollIndicator = false
        root.showsHorizontalScrollIndicator = false
        root.register(CollectionViewCell.self, forCellWithReuseIdentifier: "CellView")
        root.dataSource = self
        root.delegate = self

        root.configureLayout { layout in
            layout.isEnabled = true
            layout.width = .init(value: 100, unit: .percent)
            layout.height = .init(value: 100, unit: .percent)
        }

        let gesture = configureOnClickGesture(
            target: self,
            selector: #selector(onClicked(sender:)),
            context: context,
            uiBlockAction: block.data?.onClick
        )
        self.gesture = gesture

        self.configureLayout { layout in
            layout.isEnabled = true
            layout.position = .relative
            configureSize(layout: layout, frame: block.data?.frame, parentDirection: context.getParentDireciton())
        }
        self.addSubview(root)
        
        if block.data?.kind == CollectionKind.CAROUSEL && block.data?.pageControl == true && block.data?.fullItemWidth == true {
            let pageControl = UIPageControl(frame: CGRect(x: 0, y: 0, width: 70, height: 30))
            pageControl.numberOfPages = self.childrenCount
            pageControl.currentPage = 0
            pageControl.currentPageIndicatorTintColor = .init(white: 1, alpha: 0.8)
            pageControl.pageIndicatorTintColor = .init(white: 0.4, alpha: 0.3)
            pageControl.isUserInteractionEnabled = false
            pageControl.configureLayout { layout in
                layout.isEnabled = true
                layout.position = .absolute
                layout.bottom = .init(value: 0, unit: .point)
                layout.alignSelf = .center
            }
            self.pageControl = pageControl
            self.addSubview(pageControl)
        }

        makeDisabledStateListener(target: self, context: context, requiredFields: block.data?.onClick?.requiredFields)?.store(in: &cancellables)

        self.bindVariable()
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
            && self.block?.data?.fullItemWidth == true
            && self.block?.data?.autoScroll == true
            && self.childrenCount > 1
    }

    private func startAutoScrollTimerIfNeeded() {
        guard self.timer == nil else { return }
        guard self.shouldAutoScroll() else { return }

        let timeInterval = self.block?.data?.autoScrollInterval ?? 3.0
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
        configureBorder(view: root, frame: self.block?.data?.frame)
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
                            parentClickListener: self.gesture,
                            parentDirection: self.block?.data?.direction,
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
                            parentClickListener: self.gesture,
                            parentDirection: self.block?.data?.direction,
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
        let width = (self.block?.data?.fullItemWidth == true) ? self.frame.width : CGFloat(self.block?.data?.itemWidth ?? 0)
        return CGSize(width: width, height: CGFloat(self.block?.data?.itemHeight ?? 0))
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
        self.collectionView?.scrollToItem(at: IndexPath(item: self.counter, section: 0), at: .centeredHorizontally, animated: true)
    }
}
