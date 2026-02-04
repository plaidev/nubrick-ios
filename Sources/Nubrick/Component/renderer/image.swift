//
//  image.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
@_implementationOnly import YogaKit

class ImageView: AnimatedUIControl {
    private let image: UIImageView = UIImageView()
    private var block: UIImageBlock = UIImageBlock()
    private var context: UIBlockContext?

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

        let compiledSrc = compile(block.data?.src ?? "", context.getVariable())

        let fallbackSetting = parseImageFallbackToBlurhash(compiledSrc)
        let fallback = fallbackSetting.blurhash == "" ? UIImage() : UIImage(
            blurHash: fallbackSetting.blurhash,
            size: CGSize(width: CGFloat(fallbackSetting.width), height: CGFloat(fallbackSetting.height))
        )
        self.image.image = fallback
        // Check if image is in stretch mode (not fixed size)
        let isStretchWidth = block.data?.frame?.width == nil || block.data?.frame?.width == 0
        let isStretchHeight = block.data?.frame?.height == nil || block.data?.frame?.height == 0

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

        _ = configureOnClickGesture(
            target: self,
            action: #selector(onClicked(sender:)),
            context: context,
            event: block.data?.onClick
        )

        loadAsyncImage(url: compiledSrc, view: self, image: self.image)
        
        let handleDisabled = configureDisabled(target: self, context: context, requiredFields: block.data?.onClick?.requiredFields)
        
        guard let id = block.id, let handleDisabled = handleDisabled else {
            return
        }
        context.addFormValueListener(id, { values in
            handleDisabled(values)
        })
    }
    
    deinit {
        self.context?.removeFormValueListener(self.block.id ?? "")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureBorder(view: self, frame: self.block.data?.frame)
    }
}

func loadAsyncImageToBackgroundSrc(url: String, view: UIView) {
    guard let requestUrl = URL(string: url) else {
        return
    }
    
    let fallbackSetting = parseImageFallbackToBlurhash(url)
    let fallback = fallbackSetting.blurhash == "" ? UIImage() : UIImage(
        blurHash: fallbackSetting.blurhash,
        size: CGSize(width: CGFloat(fallbackSetting.width), height: CGFloat(fallbackSetting.height))
    )
    
    if let fallback = fallback {
        view.layer.contents = fallback.cgImage
        view.contentMode = UIView.ContentMode.scaleAspectFill
        view.clipsToBounds = true
    }
    
    Task {
        do {
            let (data, response) = try await nativebrikSession.data(from: requestUrl)
            
            await MainActor.run {
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
                view.layoutSubviews()
            }
        } catch {
            // Error handling - silently fail as before
            print("Failed to load image from \(url): \(error)")
        }
    }
}

func loadAsyncImage(url: String, view: UIView, image: UIImageView) {
    guard let requestUrl = URL(string: url) else {
        return
    }
    
    Task {
        do {
            let (data, response) = try await nativebrikSession.data(from: requestUrl)
            
            await MainActor.run {
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
                view.layoutSubviews()
            }
        } catch {
            // Error handling - silently fail as before
            print("Failed to load image from \(url): \(error)")
        }
    }
}

func isGif(_ response: URLResponse?) -> Boolean {
    guard let response = response else {
        return false
    }
    let contentType = (response as! HTTPURLResponse).allHeaderFields["Content-Type"] as? String
    guard let contentType = contentType else {
        return false
    }
    return contentType.hasSuffix("gif")
}
