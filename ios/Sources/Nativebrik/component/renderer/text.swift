import Foundation
import YogaKit
import UIKit

class TextView: AnimatedUIControl {
    var label: UILabel = UILabel()
    var block: UITextBlock = UITextBlock()
    var context: UIBlockContext?
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(block: UITextBlock, context: UIBlockContext) {
        super.init(frame: .zero)
        let showSkelton = context.isLoading() && hasPlaceholderPath(template: block.data?.value ?? "")

        self.block = block
        self.context = context
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.display = .flex
            layout.direction = .LTR
            
            configureSkelton(view: self, showSkelton: showSkelton)
        }
        
        let label = UILabel()
        label.yoga.isEnabled = true
        if let color = block.data?.color {
            label.textColor = parseColor(color)
        } else {
            label.textColor = .label
        }
        label.font = parseTextBlockDataToUIFont(block.data?.size, block.data?.weight, block.data?.design)
        let text = compile(block.data?.value ?? "", context.getVariable())
        label.text = text
        if let maxLines = block.data?.maxLines {
            label.numberOfLines = maxLines
        } else {
            label.numberOfLines = 0
        }
        configureSkeltonText(view: label, showSkelton: showSkelton)
        
        self.label = label
        self.addSubview(label)
        
        _ = configureOnClickGesture(
            target: self,
            action: #selector(onClicked(sender:)),
            context: context,
            event: block.data?.onClick
        )
        
        if let bgSrc = block.data?.frame?.backgroundSrc {
            let bgSrc = compile(bgSrc, context.getVariable())
            loadAsyncImageToBackgroundSrc(url: bgSrc, view: self)
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
        self.context?.removeFormValueListener(self.block.id ?? "")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        configureBorder(view: self, frame: self.block.data?.frame)
    }
}
