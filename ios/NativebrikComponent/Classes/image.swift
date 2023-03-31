//
//  image.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
import YogaKit

class ImageView: UIView {
    private let image: UIImageView = UIImageView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(block: UIImageBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        
        self.configureLayout { layout in
            layout.isEnabled = true
            
            configurePadding(layout: layout, frame: block.data?.frame)
            configureSize(layout: layout, frame: block.data?.frame)
            configureBorder(view: self, frame: block.data?.frame)
        }
        
        let fallbackSetting = parseImageFallbackToBlurhash(block.data?.src ?? "")
        let fallback = fallbackSetting.blurhash == "" ? UIImage() : UIImage(
            blurHash: fallbackSetting.blurhash,
            size: CGSize(width: CGFloat(fallbackSetting.width), height: CGFloat(fallbackSetting.height))
        )
        self.image.image = fallback
        self.image.configureLayout { layout in
            layout.isEnabled = true
            
            layout.maxWidth = 100%
            layout.maxHeight = 100%
            layout.width = 100%
            layout.height = 100%
            layout.minWidth = 100%
            layout.minHeight = 100%
        }
        self.image.contentMode = .scaleAspectFit
        self.image.clipsToBounds = true
        self.layer.masksToBounds = true
        
        self.addSubview(self.image)
        
        _ = configureOnClickGesture(
            target: self,
            action: #selector(onClicked(sender:)),
            context: context,
            event: block.data?.onClick
        )
        
        let imgSrc = block.data?.src ?? ""
        self.asyncLoadImage(url: imgSrc)
    }
    
    func asyncLoadImage(url: String) {
        guard let requestUrl = URL(string: url) else {
            return
        }
        URLSession.shared.dataTask(with: requestUrl) { (data, response, error) in
            DispatchQueue.main.async { [weak self] in
                if error != nil {
                    return
                }
                if let imageData = data {
                    if isGif(response) {
                        self?.image.image = UIImage.gifImageWithData(imageData)
                    } else {
                        self?.image.image = UIImage(data: imageData)
                    }
                    self?.layoutSubviews()
                } else {
                    return
                }
            }
        }.resume()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    @objc func onClicked(sender: ClickListener) {
        if let onClick = sender.onClick {
            onClick()
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
