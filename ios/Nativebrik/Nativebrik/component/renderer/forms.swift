//
//  form.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/12/14.
//

import Foundation
import UIKit
import YogaKit
import TipKit

class TooltipViewController: UIViewController, UIPopoverPresentationControllerDelegate {
    var message: String? = ""
    init(message: String, source: UIView) {
        super.init(nibName: nil, bundle: nil)
        self.message = message
        self.preferredContentSize = CGSize(width: 400, height: 32)
        self.modalPresentationStyle = .popover
        self.popoverPresentationController?.sourceView = source
        self.popoverPresentationController?.delegate = self
        self.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection([.down, .up])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .init(white: 0, alpha: 0)
        let label = UILabel(frame: CGRect(x: 16, y: 16, width: 280 - 32, height: 16))
        label.lineBreakMode = .byWordWrapping;
        label.numberOfLines = 0;
        label.text = self.message
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        self.view.addSubview(label)

        let labelHeight = label.intrinsicContentSize.height
        let labelWidth = label.intrinsicContentSize.width
        label.frame.size.height = labelHeight
        label.frame.size.width = labelWidth
        self.preferredContentSize = CGSize(width: 32 + labelWidth, height: 32 + labelHeight)
    }

    // UIPopoverPresentationControllerDelegate
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

class InputIconView: UIControl {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    init(systemName: String, message: String?, color: UIColor?, size: Int?, padding: Int?) {
        super.init(frame: .zero)
        let size = size ?? 16
        let paddingRight = padding ?? 0
        let paddingLeft = padding ?? 4

        self.configureLayout { layout in
            layout.isEnabled = true
            layout.paddingLeft = .init(integerLiteral: paddingLeft)
            layout.paddingRight = .init(integerLiteral: paddingRight)
            layout.height = .init(value: 100, unit: .percent)
            layout.width = .init(integerLiteral: paddingLeft + paddingRight + size)
            layout.alignItems = .center
            layout.justifyContent = .center
        }

        let iconView = UIImageView(image: UIImage(systemName: systemName))
        iconView.configureLayout { layout in
            layout.isEnabled = true
            layout.width = .init(integerLiteral: size)
            layout.height = .init(integerLiteral: size)
        }
        iconView.sizeToFit()
        if let color = color {
            iconView.tintColor = color
        }

        if #available(iOS 14.0, *), let message = message {
            self.addAction(.init { _ in
                if #available(iOS 17.0, *) {
                    let tooltip = TooltipViewController(message: message, source: iconView)
                    presentOnTop(window: self.window, modal: tooltip)
                }
            }, for: .touchDown)
        }

        self.addSubview(iconView)
    }

    deinit {
        if self.window?.rootViewController?.presentedViewController is TooltipViewController {
            self.window?.rootViewController?.dismiss(animated: true)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.yoga.applyLayout(preservingOrigin: true)
    }
}

class TextInputView: UIView, UITextFieldDelegate {
    let formKey: String?
    let context: UIBlockContext?
    private var block = UITextInputBlock()

    var textInput: UITextField? = nil
    var validateRegex: String? = nil
    var fontSize: Int? = nil
    var paddingRight: Int? = nil
    var errorMessage: UITooltipMessage? = nil

    required init?(coder: NSCoder) {
        self.formKey = nil
        self.context = nil
        super.init(coder: coder)
    }

    init(block: UITextInputBlock, context: UIBlockContext) {
        self.formKey = block.data?.key
        self.context = context
        super.init(frame: .zero)

        self.block = block
        self.fontSize = block.data?.size
        self.paddingRight = block.data?.frame?.paddingRight
        self.errorMessage = block.data?.errorMessage
        self.validateRegex = block.data?.regex

        var initialValue = block.data?.value
        if let formKey = self.formKey {
            if let value = self.context?.getFormValueByKey(key: formKey) as? String {
                initialValue = value
            } else {
                self.context?.writeToForm(key: formKey, value: initialValue ?? "")
            }
        }

        // wrap layout
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.width = .init(value: 100.0, unit: .percent)
            layout.flexShrink = 1
        }

        // toolbar for input
        let toolbar = UIToolbar()
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([space, doneButton], animated: true)
        toolbar.sizeToFit()

        // input layout
        let textInput = UITextField()
        self.textInput = textInput
        textInput.text = initialValue
        textInput.addTarget(self, action: #selector(onEditingChanged(sender: )), for: .editingChanged)
        textInput.textAlignment = parseTextAlign(block.data?.textAlign)
        textInput.inputAccessoryView = toolbar
        textInput.delegate = self
        textInput.configureLayout { layout in
            layout.isEnabled = true
            layout.width = .init(value: 100.0, unit: .percent)
            configurePadding(layout: layout, frame: block.data?.frame)
        }
        if let paddingLeft = block.data?.frame?.paddingLeft {
            textInput.leftView = UIView(frame: CGRect(x: 0, y: 0, width: paddingLeft, height: 0))
            textInput.leftViewMode = .always
        }
        if let paddingRight = block.data?.frame?.paddingRight {
            textInput.rightView = UIView(frame: CGRect(x: 0, y: 0, width: paddingRight, height: 0))
            textInput.rightViewMode = .always
        }

        if let color = block.data?.color {
            textInput.textColor = parseColor(color)
        } else {
            textInput.textColor = .label
        }
        textInput.font = parseTextBlockDataToUIFont(block.data?.size, block.data?.weight, block.data?.design)
        self.fontSize = block.data?.size
        if let placeholder = block.data?.placeholder {
            textInput.placeholder = placeholder
        }
        if let autocorrect = block.data?.autocorrect {
            if autocorrect {
                textInput.autocorrectionType = .yes
            } else {
                textInput.autocorrectionType = .no
            }
        } else {
            textInput.autocorrectionType = .no
        }
        if let secure = block.data?.secure {
            textInput.isSecureTextEntry = secure
        }
        textInput.autocapitalizationType = .none
        textInput.keyboardType = parserKeyboardType(block.data?.keyboardType)

        self.addSubview(textInput)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureBorder(view: self, frame: self.block.data?.frame)
    }

    @objc func doneButtonTapped() {
        self.textInput?.resignFirstResponder()
    }

    @objc func onEditingChanged(sender: UITextField) {
        guard let text = sender.text else {
            return
        }
        guard let regexPattern = self.validateRegex else {
            // when it doesnt have validation
            if let formKey = self.formKey {
                self.context?.writeToForm(key: formKey, value: text)
            }
            return
        }
        if containsPattern(text, regexPattern) {
            // when its valid
            let view = InputIconView(systemName: "checkmark.circle", message: nil, color: .systemBlue, size: self.fontSize, padding: self.paddingRight)
            sender.rightView = view
            sender.rightViewMode = .always

            if let formKey = self.formKey {
                self.context?.writeToForm(key: formKey, value: text)
            }
        } else {
            // when its not vali
            let view = InputIconView(systemName: "info.circle.fill", message: self.errorMessage?.title, color: .systemRed, size: self.fontSize, padding: self.paddingRight)
            sender.rightView = view
            sender.rightViewMode = .always

            if let formKey = self.formKey {
                self.context?.writeToForm(key: formKey, value: "")
            }
        }
        return
    }

    // UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}

class SwitchInputView: UIControl {
    let formKey: String?
    let context: UIBlockContext?
    required init?(coder: NSCoder) {
        self.context = nil
        self.formKey = nil
        super.init(coder: coder)
    }

    init(block: UISwitchInputBlock, context: UIBlockContext) {
        self.formKey = block.data?.key
        self.context = context
        super.init(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
        let toggle = UISwitch(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
        toggle.isOn = block.data?.value ?? false

        if let formKey = self.formKey {
            if let value = self.context?.getFormValueByKey(key: formKey) as? Bool {
                toggle.isOn = value
            } else {
                self.context?.writeToForm(key: formKey, value: toggle.isOn)
            }
        }

        if #available(iOS 14.0, *) {
            toggle.addAction(.init(handler: { _ in
                self.handleValueChange(toggle)
            }), for: .valueChanged)
        } else {
            toggle.addTarget(self, action: #selector(self.handleValueChange(_:)), for: .valueChanged)
        }
        self.configureLayout { layout in
            layout.isEnabled = true
        }
        self.addSubview(toggle)
    }

    @objc func handleValueChange(_ sender:UISwitch!) {
        if let formKey = self.formKey {
            self.context?.writeToForm(key: formKey, value: sender.isOn)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}
