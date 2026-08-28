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

fileprivate let placeholderPattern = "\\{\\{\\s*([a-zA-Z0-9_.-]{1,300})\\s*(?:\\|\\s*([a-zA-Z0-9_-]*)\\s*)?\\}\\}"

fileprivate let placeholderRegex: NSRegularExpression? = {
    try? NSRegularExpression(pattern: placeholderPattern, options: [])
}()

fileprivate func templatePlaceholder(from match: NSTextCheckingResult, in ns: NSString) -> TemplatePlaceholder {
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
        let path = templatePlaceholder(from: match, in: templateAsNsstring).path
        return path == "data" || path.hasPrefix("data.")
    }
}

func compile(_ template: String, _ variable: Variable?) -> String {
    guard let regex = placeholderRegex else {
        return template
    }
    let raw = variable?.value
    let ns = template as NSString
    let matches = regex.matches(in: template, range: NSRange(location: 0, length: ns.length))
    guard !matches.isEmpty else {
        return template
    }

    let result = NSMutableString(string: template)
    for match in matches.reversed() {
        let placeholder = templatePlaceholder(from: match, in: ns)
        let valueStr = formatValue(
            formatter: placeholder.formatter,
            value: variableByPath(path: placeholder.path, variable: raw)
        )
        result.replaceCharacters(in: match.range, with: valueStr)
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

