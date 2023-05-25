//
//  placeholder.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/29.
//

import Foundation

func getPlaceholderRegex() -> NSRegularExpression? {
    return try? NSRegularExpression(pattern: "\\{\\{[a-zA-Z0-9_\\.-]{1,300}\\}\\}", options: .dotMatchesLineSeparators)
}

func isPlaceholder(value: String) -> Bool {
    return getPlaceholderRegex()?.firstMatch(in: value, options: [], range: NSRange(location: 0, length: value.utf16.count)) != nil
}

func getPlaceholderPath(placeholder: String) -> String? {
    guard isPlaceholder(value: placeholder) else {
        return nil
    }
    return String(placeholder.dropFirst(2).dropLast(2))
}

func hasPlaceholderPath(template: String) -> Bool {
    guard let regex = getPlaceholderRegex() else {
        return false
    }
    let templateAsNsstring = template as NSString
    return regex.numberOfMatches(in: template, range: NSRange(location: 0, length: templateAsNsstring.length)) > 0
}

func compileTemplate(template: String, getByPath: (String) -> Any?) -> String {
    guard let regex = getPlaceholderRegex() else {
        return template
    }
    var result = template as NSString
    for _ in 1...20 {
        let range = NSRange(location: 0, length: result.length)
        guard let match = regex.firstMatch(in: result as String, range: range) else {
            break
        }
        let placeholder = result.substring(with: match.range)
        guard let placeholderPath = getPlaceholderPath(placeholder: placeholder) else {
            break
        }
        if placeholderPath == "" {
            break
        }
        let value = getByPath(placeholderPath)
        let valueStr = value.flatMap({ String.init(describing: $0 )}) ?? ""
        result = result.replacingOccurrences(of: placeholder, with: valueStr) as NSString
    }
    return result as String
}

