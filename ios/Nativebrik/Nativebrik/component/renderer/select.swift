//
//  select.swift
//  Nativebrik
//
//  Created by Takuma Jimbo on 2025/05/22.
//

import Foundation
import UIKit
import YogaKit
import TipKit

let noneValue = ""
let noneLabel = "None"

@available(iOS 15.0, *)
class SelectInputView: UIControl {
    let formKey: String?
    let context: UIBlockContext?
    private var block = UISelectInputBlock()

    private let button = UIButton(frame: .zero)
    private var initialValue: UISelectInputOption?

    required init?(coder: NSCoder) {
        self.formKey = nil
        self.context = nil
        super.init(coder: coder)
    }

    init(block: UISelectInputBlock, context: UIBlockContext) {
        self.block = block
        self.formKey = block.data?.key
        self.context = context
        super.init(frame: .zero)

        setupLayout()
        setupFormValue()

        button.configureLayout { $0.isEnabled = true }
        button.contentHorizontalAlignment = parseTextAlignToHorizontalAlignment(block.data?.textAlign)
        button.configuration = buttonConfig(hasValue: self.initialValue != nil)

        button.menu = UIMenu(children: createMenuActions())
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true

        let placeholder = (block.data?.placeholder ?? "").isEmpty ? "Please select" : block.data?.placeholder
        button.setTitle(initialValue?.value ?? placeholder, for: .normal)

        self.addSubview(button)
    }

    private func setupLayout() {
        // wrap layout
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.width = .init(value: 100.0, unit: .percent)
            layout.flexShrink = 1
        }
    }

    private func setupFormValue() {
        initialValue = block.data?.options?.first { $0.value == block.data?.value }

        guard let formKey else { return }

        if let value = context?.getFormValueByKey(key: formKey) as? String {
            initialValue = block.data?.options?.first { $0.value == value }
        } else {
            context?.writeToForm(key: formKey, value: initialValue?.value ?? noneValue)
        }
    }

    private func buttonConfig(hasValue: Bool) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        let frame = block.data?.frame
        config.contentInsets = .init(
            top: CGFloat(frame?.paddingTop ?? 0),
            leading: CGFloat(frame?.paddingLeft ?? 0),
            bottom: CGFloat(frame?.paddingBottom ?? 0),
            trailing: CGFloat(frame?.paddingRight ?? 0)
        )

        let foregroundColor: UIColor = {
            if let colorValue = block.data?.color,
               let colorResult = parseColorValueFromGenerated(colorValue) {
                switch colorResult {
                case .solid(let color):
                    return color
                case .linearGradient:
                    // Gradient not supported for text color, use default
                    return .label
                }
            }
            return .label
        }()
        config.titleTextAttributesTransformer = .init({ _ in
            return .init([
                .font: parseTextBlockDataToUIFont(self.block.data?.size, self.block.data?.weight, self.block.data?.design),
                .foregroundColor: hasValue ? foregroundColor : UIColor.placeholderText
            ])
        })
        config.baseForegroundColor = .tertiaryLabel
        return config
    }

    private func createMenuActions() -> [UIAction] {
        let handleSelect = { (action: UIAction) in
            self.button.configuration = self.buttonConfig(hasValue: true)

            if let formKey = self.formKey {
                let identifer = action.identifier.rawValue
                self.context?.writeToForm(key: formKey, value: identifer)
            }
        }

        var actions: [UIAction] = block.data?.options?.map({ option in
            return UIAction(
                title: option.label ?? option.value ?? noneLabel,
                identifier: .init(option.value ?? noneValue),
                state: option.value == initialValue?.value ? .on : .off,
                handler: handleSelect
            )
        }) ?? []

        if initialValue == nil {
            actions.insert(UIAction(
                title: block.data?.placeholder ?? noneLabel,
                identifier: .init(noneValue),
                attributes: [.hidden],
                state: .off,
                handler: {_ in }
            ), at: 0)
        }

        return actions
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureBorder(view: self, frame: self.block.data?.frame)
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
        return "\(values?.count ?? 0) items"
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
    private var block = UIMultiSelectInputBlock()

    required init?(coder: NSCoder) {
        self.formKey = nil
        self.context = nil
        super.init(coder: coder)
    }

    init(block: UIMultiSelectInputBlock, context: UIBlockContext) {
        self.block = block
        self.formKey = block.data?.key
        self.context = context
        super.init(frame: .zero)

        self.values = block.data?.value ?? []
        if let formKey = self.formKey {
            if let value = self.context?.getFormValueByKey(key: formKey) as? [String] {
                self.values = value
            } else {
                self.context?.writeToForm(key: formKey, value: self.values)
            }
        }

        // wrap layout
        self.configureLayout { layout in
            layout.isEnabled = true
            layout.width = .init(value: 100.0, unit: .percent)
            layout.flexShrink = 1
            layout.flexDirection = .row
            layout.alignItems = .center
            configurePadding(layout: layout, frame: block.data?.frame)
        }

        let label = UILabel(frame: .zero)
        self.label = label
        label.configureLayout { layout in
            layout.isEnabled = true
            layout.flexGrow = 1
        }
        var textColor: UIColor = .label
        if let colorValue = block.data?.color {
            if let colorResult = parseColorValueFromGenerated(colorValue) {
                switch colorResult {
                case .solid(let color):
                    textColor = color
                case .linearGradient:
                    // Gradient not supported for text color in select, use default
                    break
                }
            }
        }
        let text = getMultiSelectText(self.values)
        label.font = parseTextBlockDataToUIFont(block.data?.size, block.data?.weight, block.data?.design)
        label.text = text ?? block.data?.placeholder ?? "Please select"
        label.textColor = text != nil ? textColor : .placeholderText
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
                    let text = getMultiSelectText(self?.values)
                    self?.label?.text = text ?? block.data?.placeholder ?? "Please select"
                    self?.label?.textColor = text != nil ? textColor : .placeholderText

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
        configureBorder(view: self, frame: self.block.data?.frame)
    }
}
