import Foundation
import UIKit

class TextView: AnimatedUIControl {
    var label: UILabel = UILabel()
    var block: UITextBlock = UITextBlock()
    var context: UIBlockContext?
    private var formValueListenerId: String?
    private let formValueListenerInstanceId = UUID().uuidString
    private var formValueListener: FormValueListener?
    private var hasRegisteredFormValueListener = false

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
            selector: #selector(onClicked(sender:)),
            context: context,
            uiBlockAction: block.data?.onClick
        )
        
        if let bgSrc = block.data?.frame?.backgroundSrc {
            let bgSrc = compile(bgSrc, context.getVariable())
            loadAsyncImageToBackgroundSrc(url: bgSrc, view: self)
        }
        
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
}
