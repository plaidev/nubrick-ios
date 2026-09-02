//
//  image.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Combine
import Foundation
import ImageIO
import UIKit
internal import YogaKit

// Keep decoded image memory within a practical mobile-device budget.
private let maximumImagePixels = 4_096 * 4_096

@MainActor
private func boundedImage(from data: Data) -> UIImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
          let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
        return nil
    }

    let pixelWidth = width.doubleValue
    let pixelHeight = height.doubleValue
    guard pixelWidth > 0,
          pixelHeight > 0,
          pixelWidth.isFinite,
          pixelHeight.isFinite,
          pixelWidth <= Double(maximumImagePixels) / pixelHeight else {
        return nil
    }
    return UIImage(data: data)
}

class ImageView: AnimatedUIView {
    private let image: UIImageView = UIImageView()
    private var block: UIImageBlock = UIImageBlock()
    private var context: UIBlockContext?
    private var cancellables = Set<AnyCancellable>()
    private var imageLoadTask: Task<Void, Never>?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    init(block: UIImageBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        self.block = block
        self.context = context

        self.configureLayout { layout in
            layout.isEnabled = true

            // Image padding is not supported by the editor so we dont apply padding
            configureSize(layout: layout, frame: block.data?.frame, parentDirection: context.getParentDireciton())
            configureBorderWidth(layout: layout, frame: block.data?.frame)

            // image URLs include dimensions for their blurhash
            // fallback. Use them until the full image provides exact dimensions.
            if hasMissingImageDimension(block.data?.frame),
               let aspectRatio = parseImageFallbackAspectRatio(block.data?.src ?? "") {
                layout.aspectRatio = aspectRatio
            }
        }

        self.image.configureLayout { layout in
            layout.isEnabled = true

            layout.maxWidth = .init(value: 100, unit: .percent)
            layout.maxHeight = .init(value: 100, unit: .percent)
            layout.width = .init(value: 100, unit: .percent)
            layout.height = .init(value: 100, unit: .percent)
            layout.minWidth = .init(value: 100, unit: .percent)
            layout.minHeight = .init(value: 100, unit: .percent)


        }
        self.image.contentMode = parseImageContentMode(block.data?.contentMode)
        self.image.clipsToBounds = true
        self.layer.masksToBounds = true

        self.addSubview(self.image)
        self.bindVariable()

        configureOnClickGesture(context: context, uiBlockAction: block.data?.onClick)

        makeDisabledStateListener(target: self, context: context, requiredFields: block.data?.onClick?.requiredFields)?.store(in: &cancellables)
    }

    deinit {
        self.imageLoadTask?.cancel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureBorder(view: self, frame: self.block.data?.frame)
    }

    private func bindVariable() {
        guard let context = self.context else {
            return
        }

        let srcTemplate = self.block.data?.src ?? ""
        let showSkeltonOnLoading = hasDataPlaceholderPath(template: srcTemplate)

        context.loadingPublisher()
            .sink { [weak self] loading in
                guard let self else { return }
                if loading && showSkeltonOnLoading {
                    configureSkelton(view: self)
                } else {
                    removeSkelton(view: self, frame: self.block.data?.frame)
                }
            }
            .store(in: &self.cancellables)

        guard hasPlaceholderPath(template: srcTemplate) else {
            self.applyImageSource(srcTemplate)
            return
        }

        context.variablePublisher()
            .map { compile(srcTemplate, $0) }
            .removeDuplicates()
            .sink { [weak self] src in
                self?.applyImageSource(src)
            }
            .store(in: &self.cancellables)
    }

    private func applyImageSource(_ src: String) {
        self.configureImageAspectRatio(src)

        let fallbackSetting = parseImageFallbackToBlurhash(src)
        self.image.image = fallbackSetting.blurhash == "" ? UIImage() : UIImage(
            blurHash: fallbackSetting.blurhash,
            size: CGSize(width: CGFloat(fallbackSetting.width), height: CGFloat(fallbackSetting.height))
        )
        self.imageLoadTask?.cancel()
        self.imageLoadTask = loadAsyncImage(
            url: src,
            image: self.image,
            layoutRoot: self.context?.getLayoutInvalidationRoot(),
            onImageLoaded: { [weak self] image in
                self?.configureImageAspectRatio(imageAspectRatio(
                    width: image.size.width,
                    height: image.size.height
                ))
            }
        )
    }

    private func configureImageAspectRatio(_ src: String) {
        self.configureImageAspectRatio(parseImageFallbackAspectRatio(src))
    }

    private func configureImageAspectRatio(_ aspectRatio: CGFloat?) {
        guard hasMissingImageDimension(self.block.data?.frame) else {
            return
        }

        self.yoga.aspectRatio = aspectRatio ?? .nan
        self.context?.getLayoutInvalidationRoot()?.setNeedsLayout()
    }
}

private func hasMissingImageDimension(_ frame: FrameData?) -> Bool {
    hasMissingImageDimension(width: frame?.width, height: frame?.height)
}

func hasMissingImageDimension(width: Int?, height: Int?) -> Bool {
    width == nil || height == nil
}

@MainActor
func loadAsyncImageToBackgroundSrc(url: String, view: UIView) -> Task<Void, Never>? {
    let fallbackSetting = parseImageFallbackToBlurhash(url)
    let fallback = fallbackSetting.blurhash == "" ? UIImage() : UIImage(
        blurHash: fallbackSetting.blurhash,
        size: CGSize(width: CGFloat(fallbackSetting.width), height: CGFloat(fallbackSetting.height))
    )

    view.layer.contents = fallback?.cgImage
    view.contentMode = UIView.ContentMode.scaleAspectFill
    view.clipsToBounds = true

    guard let requestUrl = URL(string: url) else {
        return nil
    }
    
    return Task {
        do {
            let data = try await fetchImageData(from: requestUrl)
            try Task.checkCancellation()
            
            await MainActor.run {
                guard !Task.isCancelled else {
                    return
                }
                // TODO: Add animated GIF playback with ImageIO's CGAnimateImageDataWithBlock.
                guard let image = boundedImage(from: data) else {
                    return
                }
                UIView.transition(
                    with: view,
                    duration: 0.2,
                    options: .transitionCrossDissolve,
                    animations: {
                        view.layer.contents = image.cgImage
                        view.contentMode = UIView.ContentMode.scaleAspectFill
                        view.clipsToBounds = true
                    },
                    completion: nil)
            }
        } catch is CancellationError {
        } catch {
            // Error handling - silently fail as before
            print("Failed to load image from \(url): \(error)")
        }
    }
}

@MainActor
func loadAsyncImage(
    url: String,
    image: UIImageView,
    layoutRoot: UIView?,
    onImageLoaded: ((UIImage) -> Void)? = nil
) -> Task<Void, Never>? {
    guard let requestUrl = URL(string: url) else {
        return nil
    }
    
    return Task {
        do {
            let data = try await fetchImageData(from: requestUrl)
            try Task.checkCancellation()
            
            await MainActor.run {
                guard !Task.isCancelled else {
                    return
                }
                // TODO: Add animated GIF playback with ImageIO's CGAnimateImageDataWithBlock.
                guard let loadedImage = boundedImage(from: data) else {
                    return
                }

                UIView.transition(
                    with: image,
                    duration: 0.2,
                    options: .transitionCrossDissolve,
                    animations: {
                        image.image = loadedImage
                    },
                    completion: nil)
                onImageLoaded?(loadedImage)
                if let layoutRoot {
                    invalidateYogaLayout(from: image, layoutRoot: layoutRoot)
                }
            }
        } catch is CancellationError {
        } catch {
            // Error handling - silently fail as before
            print("Failed to load image from \(url): \(error)")
        }
    }
}
