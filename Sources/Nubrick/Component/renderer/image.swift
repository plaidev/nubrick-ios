//
//  image.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Combine
import Foundation
import UIKit
internal import YogaKit

class ImageView: AnimatedUIControl {
    private let image: UIImageView = UIImageView()
    private var block: UIImageBlock = UIImageBlock()
    private var context: UIBlockContext?
    private var formValueListenerId: String?
    private let formValueListenerInstanceId = UUID().uuidString
    private var formValueListener: FormValueListener?
    private var hasRegisteredFormValueListener = false
    private var cancellables = Set<AnyCancellable>()
    private var imageLoadTask: Task<Void, Never>?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    init(block: UIImageBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        self.block = block
        self.context = context

        let showSkelton = context.isLoading() && hasPlaceholderPath(template: block.data?.src ?? "")

        self.configureLayout { layout in
            layout.isEnabled = true

            configurePadding(layout: layout, frame: block.data?.frame)
            configureSize(layout: layout, frame: block.data?.frame, parentDirection: context.getParentDireciton())

            configureSkelton(view: self, showSkelton: showSkelton)
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

        _ = configureOnClickGesture(
            target: self,
            selector: #selector(onClicked(sender:)),
            context: context,
            uiBlockAction: block.data?.onClick
        )

        let handleDisabled = makeDisabledStateListener(
            target: self,
            context: context,
            requiredFields: block.data?.onClick?.requiredFields
        )

        if let id = block.id, let handleDisabled = handleDisabled {
            self.formValueListenerId = "\(id)::\(self.formValueListenerInstanceId)"
            self.formValueListener = handleDisabled
        }
    }

    private func registerFormValueListenerIfNeeded() {
        guard !self.hasRegisteredFormValueListener else { return }
        guard
            let id = self.formValueListenerId,
            let listener = self.formValueListener,
            let context = self.context
        else { return }

        context.addFormValueListener(id, listener)
        listener(context.getFormValues())
        self.hasRegisteredFormValueListener = true
    }

    private func unregisterFormValueListenerIfNeeded() {
        guard self.hasRegisteredFormValueListener else { return }
        guard let id = self.formValueListenerId else { return }

        self.context?.removeFormValueListener(id)
        self.hasRegisteredFormValueListener = false
    }

    deinit {
        self.imageLoadTask?.cancel()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if self.window == nil {
            self.unregisterFormValueListenerIfNeeded()
        } else {
            self.registerFormValueListenerIfNeeded()
        }
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
        let fallbackSetting = parseImageFallbackToBlurhash(src)
        self.image.image = fallbackSetting.blurhash == "" ? UIImage() : UIImage(
            blurHash: fallbackSetting.blurhash,
            size: CGSize(width: CGFloat(fallbackSetting.width), height: CGFloat(fallbackSetting.height))
        )
        self.imageLoadTask?.cancel()
        self.imageLoadTask = loadAsyncImage(
            url: src,
            image: self.image,
            layoutRoot: self.context?.getLayoutInvalidationRoot()
        )
    }
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
            let (data, response) = try await nativebrikSession.data(from: requestUrl)
            try Task.checkCancellation()
            
            await MainActor.run {
                guard !Task.isCancelled else {
                    return
                }
                if isGif(response) {
                    guard let image = UIImage.gifImageWithData(data) else {
                        return
                    }
                    UIView.transition(
                        with: view,
                        duration: 0.2,
                        options: .transitionCrossDissolve) {
                            view.layer.contents = image.cgImage
                            view.contentMode = UIView.ContentMode.scaleAspectFill
                            view.clipsToBounds = true
                        }
                } else {
                    guard let image = UIImage(data: data) else {
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
            }
        } catch is CancellationError {
        } catch {
            // Error handling - silently fail as before
            print("Failed to load image from \(url): \(error)")
        }
    }
}

@MainActor
func loadAsyncImage(url: String, image: UIImageView, layoutRoot: UIView?) -> Task<Void, Never>? {
    guard let requestUrl = URL(string: url) else {
        return nil
    }
    
    return Task {
        do {
            let (data, response) = try await nativebrikSession.data(from: requestUrl)
            try Task.checkCancellation()
            
            await MainActor.run {
                guard !Task.isCancelled else {
                    return
                }
                if isGif(response) {
                    UIView.transition(
                        with: image,
                        duration: 0.2,
                        options: .transitionCrossDissolve,
                        animations: {
                            image.image = UIImage.gifImageWithData(data)
                        },
                        completion: nil)
                } else {
                    UIView.transition(
                        with: image,
                        duration: 0.2,
                        options: .transitionCrossDissolve,
                        animations: {
                            image.image = UIImage(data: data)
                        },
                        completion: nil)
                }
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

func isGif(_ response: URLResponse?) -> Boolean {
    guard let httpResponse = response as? HTTPURLResponse else {
        return false
    }

    let contentType = httpResponse.allHeaderFields.first { key, _ in
        guard let key = key as? String else {
            return false
        }
        return key.caseInsensitiveCompare("Content-Type") == .orderedSame
    }?.value as? String

    guard let contentType = contentType else {
        return false
    }
    return contentType.lowercased().hasSuffix("gif")
}
