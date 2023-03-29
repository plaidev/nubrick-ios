import Foundation
import YogaKit
import UIKit

class TextView: UIView {
    var label: UILabel = UILabel()
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(block: UITextBlock, context: UIBlockContext) {
        super.init(frame: .zero)

        self.configureLayout { layout in
            layout.isEnabled = true
            layout.display = .flex
            layout.direction = .LTR
            configureBorder(view: self, frame: block.data?.frame)
        }
        
        let label = UILabel()
        label.yoga.isEnabled = true
        label.textColor = parseColor(block.data?.color)
        label.font = parseTextBlockDataToUIFont(block.data)
        label.text = block.data?.value ?? ""
        label.numberOfLines = 0
        
        self.label = label
        self.addSubview(label)
        
        _ = configureOnClickGesture(
            target: self,
            action: #selector(onClicked(sender:)),
            context: context,
            event: block.data?.onClick
        )
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
