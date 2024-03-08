//
//  compiler.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation

fileprivate struct TemplatePlaceholder {
    let path: String
    let formatter: String
}

fileprivate func getPlaceholderRegex() -> NSRegularExpression? {
    return try? NSRegularExpression(pattern: "\\{\\{[a-zA-Z0-9_\\.-| ]{1,300}\\}\\}", options: .dotMatchesLineSeparators)
}

fileprivate func isPlaceholder(value: String) -> Bool {
    return getPlaceholderRegex()?.firstMatch(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count)) != nil
}

fileprivate func getPlaceholder(placeholder: String) -> TemplatePlaceholder? {
    guard isPlaceholder(value: placeholder) else {
        return nil
    }
    let rawIdentifiers = placeholder.dropFirst(2).dropLast(2)
    let identifiers = rawIdentifiers.split(separator: "|")
    
    var path = ""
    if identifiers.count >= 1 {
        path = String(identifiers[0]).trimmingCharacters(in: CharacterSet([" "]))
    }
    
    var formatter: String = ""
    if identifiers.count >= 2 {
        formatter = String(identifiers[1]).trimmingCharacters(in: CharacterSet([" "]))
    }
    return TemplatePlaceholder(path: path, formatter: formatter)
}

func hasPlaceholderPath(template: String) -> Bool {
    guard let regex = getPlaceholderRegex() else {
        return false
    }
    let templateAsNsstring = template as NSString
    return regex.numberOfMatches(in: template, range: NSRange(location: 0, length: templateAsNsstring.length)) > 0
}

@available(*, deprecated, renamed: "compile", message: "deprecated")
func compileTemplate(template: String, getByPath: (String) -> Any?) -> String {
    guard let regex = getPlaceholderRegex() else {
        return template
    }
    var result = template as NSString
    for _ in 1...20 { // not to loop infinitly, limit to the 20 loops at maximum.
        // search the first matched {{palceholder}}, and replace it by a value.
        let range = NSRange(location: 0, length: result.length)
        guard let match = regex.firstMatch(in: result as String, range: range) else {
            break
        }
        let rawPlaceholder = result.substring(with: match.range)
        guard let placeholder = getPlaceholder(placeholder: rawPlaceholder) else {
            break
        }
        if placeholder.path == "" {
            break
        }
        let value = getByPath(placeholder.path)
        
        // format value when the placeholer is like {{ path | formatter }}
        var valueStr = formatValue(formatter: placeholder.formatter, value: value)
        result = result.replacingOccurrences(of: rawPlaceholder, with: valueStr) as NSString
    }
    return result as String
}

func compile(_ template: String, _ variable: Any?) -> String {
    guard let regex = getPlaceholderRegex() else {
        return template
    }
    var result = template as NSString
    for _ in 1...20 { // not to loop infinitly, limit to the 20 loops at maximum.
        // search the first matched {{palceholder}}, and replace it by a value.
        let range = NSRange(location: 0, length: result.length)
        guard let match = regex.firstMatch(in: result as String, range: range) else {
            break
        }
        let rawPlaceholder = result.substring(with: match.range)
        guard let placeholder = getPlaceholder(placeholder: rawPlaceholder) else {
            break
        }
        if placeholder.path == "" {
            break
        }
        let value = variableByPath(path: placeholder.path, variable: variable)
        
        // format value when the placeholer is like {{ path | formatter }}
        var valueStr = formatValue(formatter: placeholder.formatter, value: value)
        result = result.replacingOccurrences(of: rawPlaceholder, with: valueStr) as NSString
    }
    return result as String
}


func variableByPath(path: String, variable: Any?) -> Any? {
    let keys = path.split(separator: ".")
    if keys.isEmpty {
        return nil
    }
    var current = variable
    for key in keys {
        if (key == "$") {
            current = variable
        } else {
            if let dict = current as? [String: Any] {
                let child = dict.first(where: { $0.key == key })
                current = child?.value
            } else {
                return nil
            }
        }
    }
    return current
}
