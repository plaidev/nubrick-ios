//
//  form.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/12/14.
//

import Foundation
import UIKit
import YogaKit

class TextInputView: UIView, UITextFieldDelegate {
    var textInput: UITextField? = nil
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(block: UITextInputBlock) {
        super.init(frame: .zero)
        
        // wrap layout
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.width = YGValueUndefined
            layout.width = .init(value: 100.0, unit: .percent)
            layout.flexShrink = 1
        }
        configureBorder(view: self, frame: block.data?.frame)
        
        // toolbar for input
        let toolbar = UIToolbar()
        let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([space, doneButton], animated: true)
        toolbar.sizeToFit()

        // input layout
        let textInput = UITextField()
        self.textInput = textInput
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
        if let placeholder = block.data?.placeholder {
            textInput.placeholder = placeholder
        }
        if let autocorrect = block.data?.autocorrect {
            if autocorrect {
                textInput.autocorrectionType = .yes
            } else {
                textInput.autocorrectionType = .no
            }
        }
        if let secure = block.data?.secure {
            textInput.isSecureTextEntry = secure
        }
        textInput.keyboardType = parserKeyboardType(block.data?.keyboardType)

        self.addSubview(textInput)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    @objc func doneButtonTapped() {
        self.textInput?.resignFirstResponder()
    }
    
    // UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}
