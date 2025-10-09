//
//  collection.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/31.
//

import Foundation
import UIKit
import YogaKit

class CollectionViewCell: UICollectionViewCell {
    var view: UIView?
    func setView(view: UIView) {
        self.contentView.subviews.forEach({ $0.removeFromSuperview() })
        self.contentView.configureLayout { layout in
            layout.isEnabled = true
            layout.justifyContent = .center
            layout.alignItems = .center
        }
        self.view = view
        self.contentView.addSubview(view)
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

    override init(frame: CGRect) {
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

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

class CollectionView: AnimatedUIControl, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let block: UICollectionBlock?
    private let context: UIBlockContext
    private var childrenCount: Int = 0
    private var isReferenced: Bool = false
    private var data: [Any]? = nil
    private var gesture: ClickListener? = nil
    private var layout: UICollectionViewFlowLayout? = nil
    private var pageControl: UIPageControl? = nil
    private var collectionView: UICollectionView? = nil
    
    // for auto scroll
    private var timer: Timer? = nil
    private var counter: Int = 0
    
    required init?(coder aDecoder: NSCoder) {
        self.block = nil
        self.context = UIBlockContext(UIBlockContextInit())
        self.childrenCount = 0
        self.isReferenced = false
        self.data = nil
        super.init(coder: aDecoder)
    }
    
    init(block: UICollectionBlock, context: UIBlockContext) {
        self.block = block
        self.context = context
        if let reference = block.data?.reference {
            if let data = context.getArrayByReferenceKey(key: reference) {
                self.childrenCount = data.count
                self.isReferenced = true
                self.data = data
            }
        }

        if !self.isReferenced {
            self.childrenCount = block.data?.children?.count ?? 0
        }

        super.init(frame: .zero)

        let layout = getCollectionLayout(block)
        self.layout = layout
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
        root.showsVerticalScrollIndicator = false
        root.showsHorizontalScrollIndicator = false
        root.register(CollectionViewCell.self, forCellWithReuseIdentifier: "CellView")
        root.dataSource = self
        root.delegate = self

        root.configureLayout { layout in
            layout.isEnabled = true
            configureSize(layout: layout, frame: block.data?.frame, parentDirection: context.getParentDireciton())
        }

        let gesture = configureOnClickGesture(
            target: self,
            action: #selector(onClicked(sender:)),
            context: context,
            event: block.data?.onClick
        )
        self.gesture = gesture

        self.configureLayout { layout in
            layout.isEnabled = true
            layout.position = .relative
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
        
        if block.data?.kind == CollectionKind.CAROUSEL && block.data?.fullItemWidth == true && block.data?.autoScroll == true {
            let timeInterval = block.data?.autoScrollInterval ?? 3.0
            DispatchQueue.main.async { [self] in
                self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(timeInterval), target: self, selector: #selector(automaticScroll), userInfo: nil, repeats: true)
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
        self.timer?.invalidate()
        self.context.removeFormValueListener(self.block?.id ?? "")
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
                guard let childData = self.data?[indexPath.item] else {
                    return cell
                }
                let childView = UIViewBlock(
                    data: child,
                    context: self.context.instanciateFrom(
                        UIBlockContextChildInit(
                            childData: childData,
                            parentClickListener: self.gesture,
                            parentDirection: self.block?.data?.direction
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
                            parentDirection: self.block?.data?.direction
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
        let size = CGSize(width: width, height: CGFloat(self.block?.data?.itemHeight ?? 0))
        self.layout?.itemSize = size
        return size
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.pageControl?.currentPage = getCurrentPage()
    }
        
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.pageControl?.currentPage = getCurrentPage()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.pageControl?.currentPage = getCurrentPage()
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
    
    @objc func automaticScroll() {
        if self.counter >= self.childrenCount - 1 {
            self.counter = 0
        } else {
            self.counter += 1
        }
        self.collectionView?.scrollToItem(at: IndexPath(item: self.counter, section: 0), at: .centeredHorizontally, animated: true)
    }
}
