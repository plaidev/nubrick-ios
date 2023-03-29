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
        
        // todo
        let fallback = UIImage()
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
        self.asyncLoadImage(url: imgSrc, fallback: fallback)
    }
    
    func asyncLoadImage(url: String, fallback: UIImage? = nil) {
        guard let requestUrl = URL(string: url) else {
            self.image.image = fallback
            return
        }
        URLSession.shared.dataTask(with: requestUrl) { (data, response, error) in
            DispatchQueue.main.async { [weak self] in
                if error != nil {
                    self?.image.image = fallback
                    return
                }
                if let imageData = data {
                    self?.image.image = UIImage(data: imageData)
                    self?.layoutSubviews()
                } else {
                    self?.image.image = fallback
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
