//
//  compiler.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation

fileprivate struct TemplatePlaceholder {
    let path: String
    let formatter: String
}

// Same grammar as nativebrik front / Go: {{ path }} and {{ path | formatter }}.
fileprivate let placeholderPattern = "\\{\\{\\s*([a-zA-Z0-9_.-]{1,300})\\s*(?:\\|\\s*([a-zA-Z0-9_-]*)\\s*)?\\}\\}"

fileprivate let placeholderRegex: NSRegularExpression? = {
    try? NSRegularExpression(pattern: placeholderPattern, options: [])
}()

fileprivate func getPlaceholder(placeholder: String) -> TemplatePlaceholder? {
    guard let regex = placeholderRegex else {
        return nil
    }
    let ns = placeholder as NSString
    let range = NSRange(location: 0, length: ns.length)
    guard let match = regex.firstMatch(in: placeholder, range: range),
          match.range.location == 0,
          match.range.length == ns.length else {
        return nil
    }
    let path = ns.substring(with: match.range(at: 1))
    var formatter = ""
    if match.numberOfRanges > 2 {
        let formatterRange = match.range(at: 2)
        if formatterRange.location != NSNotFound {
            formatter = ns.substring(with: formatterRange)
        }
    }
    return TemplatePlaceholder(path: path, formatter: formatter)
}

func hasPlaceholderPath(template: String) -> Bool {
    guard let regex = placeholderRegex else {
        return false
    }
    let templateAsNsstring = template as NSString
    return regex.numberOfMatches(in: template, range: NSRange(location: 0, length: templateAsNsstring.length)) > 0
}

func hasDataPlaceholderPath(template: String) -> Bool {
    guard let regex = placeholderRegex else {
        return false
    }
    let templateAsNsstring = template as NSString
    let matches = regex.matches(in: template, range: NSRange(location: 0, length: templateAsNsstring.length))
    return matches.contains { match in
        let rawPlaceholder = templateAsNsstring.substring(with: match.range)
        guard let placeholder = getPlaceholder(placeholder: rawPlaceholder) else {
            return false
        }
        return placeholder.path == "data" || placeholder.path.hasPrefix("data.")
    }
}

func compile(_ template: String, _ variable: Variable?) -> String {
    guard let regex = placeholderRegex else {
        return template
    }
    let raw = variable?.value
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
        let value = variableByPath(path: placeholder.path, variable: raw)

        // format value when the placeholer is like {{ path | formatter }}
        let valueStr = formatValue(formatter: placeholder.formatter, value: value)
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
        if let dict = current as? [String: Any] {
            let child = dict.first(where: { $0.key == key })
            current = child?.value
        } else {
            return nil
        }
    }
    return current
}

