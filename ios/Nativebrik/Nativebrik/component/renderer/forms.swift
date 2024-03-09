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
        
        self.fontSize = block.data?.size
        self.paddingRight = block.data?.frame?.paddingRight
        self.errorMessage = block.data?.errorMessage
        self.validateRegex = block.data?.regex
        
        var initialValue = block.data?.value
        if let formKey = self.formKey {
            if let value = self.context?.getFormValueByKey(key: formKey) as? String {
                initialValue = value
            }
        }
        
        // wrap layout
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.height = YGValueUndefined
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

class SelectInputView: UIControl {
    let formKey: String?
    let context: UIBlockContext?
    required init?(coder: NSCoder) {
        self.formKey = nil
        self.context = nil
        super.init(coder: coder)
    }
    
    init(block: UISelectInputBlock, context: UIBlockContext) {
        self.formKey = block.data?.key
        self.context = context
        super.init(frame: .zero)
        
        // wrap layout
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.width = YGValueUndefined
            layout.width = .init(value: 100.0, unit: .percent)
            layout.flexShrink = 1
        }
        configureBorder(view: self, frame: block.data?.frame)
        
        var initialValue = block.data?.options?.first(where: { option in
            if option.value == block.data?.value {
                return true
            } else {
                return false
            }
        })
        if let formKey = self.formKey {
            if let value = self.context?.getFormValueByKey(key: formKey) as? String {
                let found = block.data?.options?.first(where: { option in
                    if option.value == value {
                        return true
                    } else {
                        return false
                    }
                })
                if let found = found {
                    initialValue = found
                }
            }
        }
        
        let button = UIButton(frame: .zero)
        button.configureLayout { layout in
            layout.isEnabled = true
        }
        if let color = block.data?.color {
            button.setTitleColor(parseColor(color), for: .normal)
        } else {
            button.setTitleColor(.label, for: .normal)
        }
        button.contentHorizontalAlignment = parseTextAlignToHorizontalAlignment(block.data?.textAlign)
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            let frame = block.data?.frame
            config.contentInsets = .init(
                top: CGFloat(frame?.paddingTop ?? 0),
                leading: CGFloat(frame?.paddingLeft ?? 0),
                bottom: CGFloat(frame?.paddingBottom ?? 0),
                trailing: CGFloat(frame?.paddingRight ?? 0)
            )
            var foregroundColor: UIColor = .label
            if let color = block.data?.color {
                foregroundColor = parseColor(color)
            }
            config.titleTextAttributesTransformer = .init({ _ in
                return .init([
                    .font: parseTextBlockDataToUIFont(block.data?.size, block.data?.weight, block.data?.design),
                    .foregroundColor: foregroundColor
                ])
            })
            config.baseForegroundColor = .tertiaryLabel
            button.configuration = config
        }
        
        if #available(iOS 14.0, *) {
            let handleSelect = { (action: UIAction) in
                button.setTitle(action.title, for: .application)
                if let formKey = self.formKey {
                    let identifer = action.identifier.rawValue
                    self.context?.writeToForm(key: formKey, value: identifer)
                }
            }
            let actions: [UIAction] = block.data?.options?.map({ option in
                return UIAction(
                    title: option.label ?? option.value ?? "None",
                    identifier: UIAction.Identifier(option.value ?? "None"),
                    state: option.value == initialValue?.value ? .on : .off,
                    handler: handleSelect
                )
            }) ?? []
            button.menu = UIMenu(children: actions)
            button.showsMenuAsPrimaryAction = true
            if #available(iOS 15.0, *) {
                button.changesSelectionAsPrimaryAction = true
            }
        }
        
        self.addSubview(button)
    }
    
    deinit {
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
}

func getMultiSelectText(_ values: [String]?) -> String? {
    switch values?.count {
    case nil:
        return nil
    case 0:
        return nil
    case 1:
        return values?[0] ?? nil
    default:
        return "\(values?.count ?? 0)"
    }
}

class MultiSelectTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    let options: [UISelectInputOption]
    var selectedOptions: [UISelectInputOption] = []
    var onSelect: (_ options: [UISelectInputOption]) -> Void = { _ in }

    required init?(coder: NSCoder) {
        self.options = []
        self.selectedOptions = []
        super.init(coder: coder)
    }

    init(values: [String]?, options: [UISelectInputOption]?, onSelect: @escaping (_ options: [UISelectInputOption]) -> Void) {
        self.options = options ?? []
        self.onSelect = onSelect
        var selected: [UISelectInputOption] = []
        
        values?.forEach({ value in
            let _ = options?.first(where: { option in
                guard let optionValue = option.value else {
                    return false
                }
                if optionValue == value {
                    selected.append(option)
                    return true
                } else {
                    return false
                }
            })
        })
        self.selectedOptions = selected
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .formSheet
        if #available(iOS 15.0, *) {
            if let sheet = self.sheetPresentationController {
                sheet.detents = .init([.large(), .medium()])
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tableView = UITableView(frame: .init(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height), style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MyCell")
        tableView.dataSource = self
        tableView.delegate = self
        self.view.addSubview(tableView)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Select"
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        let cellOption = self.options[indexPath.row]
        if cell.accessoryType == .none {
            cell.accessoryType = .checkmark
            
            self.selectedOptions = self.selectedOptions.filter({ option in
                if option.value == cellOption.value {
                    return false
                } else {
                    return true
                }
            })
            self.selectedOptions.append(cellOption)
        } else {
            cell.accessoryType = .none
            
            self.selectedOptions = self.selectedOptions.filter({ option in
                if option.value == cellOption.value {
                    return false
                } else {
                    return true
                }
            })
        }
        
        self.onSelect(self.selectedOptions)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.options.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyCell", for: indexPath as IndexPath)
        let cellOption = self.options[indexPath.row]
        cell.textLabel!.text = "\(cellOption.value ?? "")"
        let selectedCellOption = self.selectedOptions.first(where: { option in
           if option.value == cellOption.value {
               return true
           } else {
               return false
           }
        })
        if selectedCellOption != nil {
            cell.accessoryType = .checkmark
        }
        
        return cell
    }
}

class MultiSelectInputView: UIControl {
    let formKey: String?
    let context: UIBlockContext?
    var values: [String] = []
    var label: UILabel?

    required init?(coder: NSCoder) {
        self.formKey = nil
        self.context = nil
        super.init(coder: coder)
    }
    
    init(block: UIMultiSelectInputBlock, context: UIBlockContext) {
        self.formKey = block.data?.key
        self.context = context
        super.init(frame: .zero)
        
        self.values = block.data?.value ?? []
        if let formKey = self.formKey {
            if let value = self.context?.getFormValueByKey(key: formKey) as? [String] {
                self.values = value
            }
        }
        
        // wrap layout
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.height = YGValueUndefined
            layout.width = .init(value: 100.0, unit: .percent)
            layout.flexShrink = 1
            layout.flexDirection = .row
            layout.alignItems = .center
            configurePadding(layout: layout, frame: block.data?.frame)
        }
        configureBorder(view: self, frame: block.data?.frame)
        
        let label = UILabel(frame: .zero)
        self.label = label
        label.configureLayout { layout in
            layout.isEnabled = true
            layout.flexGrow = 1
        }
        var textColor: UIColor = .label
        if let color = block.data?.color {
            textColor = parseColor(color)
        }
        label.textColor = textColor
        label.font = parseTextBlockDataToUIFont(block.data?.size, block.data?.weight, block.data?.design)
        label.text = getMultiSelectText(self.values) ?? block.data?.placeholder ?? "None"
        label.numberOfLines = 0
        label.textAlignment = parseTextAlign(block.data?.textAlign)

        let iconView = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(weight: .semibold)))
        iconView.configureLayout { layout in
            layout.isEnabled = true
            layout.alignItems = .center
            layout.justifyContent = .center
            layout.width = .init(integerLiteral: 9)
            layout.height = .init(integerLiteral: 11)
            layout.marginRight = .init(integerLiteral: 4)
            layout.marginLeft = .init(integerLiteral: 4)
        }
        iconView.tintColor = .tertiaryLabel
        
        self.addSubview(label)
        self.addSubview(iconView)
        
        if #available(iOS 14.0, *) {
            self.addAction(.init { _ in
                let tableView = MultiSelectTableViewController(values: self.values, options: block.data?.options) { [weak self] options in
                    var values: [String] = []
                    options.forEach { option in
                        guard let value = option.value else {
                            return
                        }
                        values.append(value)
                    }
                    self?.values = values
                    self?.label?.text = getMultiSelectText(self?.values) ?? block.data?.placeholder ?? "None"
                    
                    if let formKey = self?.formKey {
                        self?.context?.writeToForm(key: formKey, value: values)
                    }
                }
                presentOnTop(window: self.window, modal: tableView)
            }, for: .touchDown)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
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
            layout.width = YGValueUndefined
            layout.height = YGValueUndefined
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
