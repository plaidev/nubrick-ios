import Combine
import Foundation
import UIKit

private let defaultTextLineHeightRatio: Float = 1.2

class TextView: AnimatedUIView, BackgroundImageObserver {
    var label: UILabel = UILabel()
    var block: UITextBlock = UITextBlock()
    var context: UIBlockContext?
    var cancellables = Set<AnyCancellable>()
    var backgroundImageLoadTask: Task<Void, Never>?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(block: UITextBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        self.block = block
        self.context = context
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.display = .flex
            layout.flexDirection = .row
            layout.direction = .LTR
            layout.alignItems = .center
            configurePadding(layout: layout, frame: block.data?.frame)
            configureBorderWidth(layout: layout, frame: block.data?.frame)
            configureSize(
                layout: layout, frame: block.data?.frame,
                parentDirection: context.getParentDireciton())
        }
        let label = UILabel()
        label.yoga.isEnabled = true
        if let color = block.data?.color {
            label.textColor = parseColor(color)
        } else {
            label.textColor = .label
        }
        label.adjustsFontForContentSizeCategory = true
        if let maxLines = block.data?.maxLines {
            label.numberOfLines = maxLines
        } else {
            label.numberOfLines = 0
        }
        
        self.label = label
        self.addSubview(label)
        self.bindVariable()
        
        configureOnClickGesture(context: context, uiBlockAction: block.data?.onClick)
        
        makeDisabledStateListener(target: self, context: context, requiredFields: block.data?.onClick?.requiredFields)?.store(in: &cancellables)
    }

    deinit {
        self.backgroundImageLoadTask?.cancel()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        configureBorder(view: self, frame: self.block.data?.frame)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory else { return }

        setText(label.attributedText?.string ?? label.text ?? "")
        invalidateYogaLayout(from: label, layoutRoot: context?.getLayoutInvalidationRoot())
    }

    private func setText(_ text: String) {
        let baseFont = parseTextBlockDataToUIFont(
            block.data?.size, block.data?.weight, block.data?.design)
        let metrics = UIFontMetrics.default
        let font = metrics.scaledFont(for: baseFont, compatibleWith: traitCollection)
        let baseLineHeight = CGFloat(
            block.data?.lineHeight
                ?? Float(block.data?.size ?? 16) * defaultTextLineHeightRatio)
        let lineHeight = metrics.scaledValue(
            for: baseLineHeight,
            compatibleWith: traitCollection)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight

        label.font = font
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle,
            ])
    }

    private func bindVariable() {
        guard let context = self.context else {
            return
        }

        let textTemplate = self.block.data?.value ?? ""
        let showSkeltonOnLoading = hasDataPlaceholderPath(template: textTemplate)

        if hasPlaceholderPath(template: textTemplate) {
            var shouldInvalidateLayout = false
            var previousText: String?
            let textPublisher = context.variablePublisher()
                .map { compile(textTemplate, $0) }
                .removeDuplicates()

            context.loadingPublisher()
                .combineLatest(textPublisher)
                .removeDuplicates { previous, current in
                    previous.0 == current.0 && previous.1 == current.1
                }
                .sink { [weak self] loading, text in
                    guard let self else { return }
                    if loading && showSkeltonOnLoading {
                        configureSkelton(view: self)
                        configureSkeltonText(view: self.label)
                        shouldInvalidateLayout = true
                        return
                    }

                    removeSkelton(view: self, frame: self.block.data?.frame)
                    self.setText(text)
                    if let color = self.block.data?.color {
                        self.label.textColor = parseColor(color)
                    } else {
                        self.label.textColor = .label
                    }
                    if shouldInvalidateLayout && previousText != text {
                        invalidateYogaLayout(from: self.label, layoutRoot: context.getLayoutInvalidationRoot())
                    }
                    previousText = text
                    shouldInvalidateLayout = true
                }
                .store(in: &self.cancellables)
        } else {
            self.setText(textTemplate)
        }

        if let template = self.block.data?.frame?.backgroundSrc {
            observeBackgroundImage(context: context, urlTemplate: template)
        }
    }
}
