import Foundation

enum CurrencyInputFormatter {
    static func sanitized(
        _ input: String,
        allowsNegative: Bool = false,
        maximumFractionDigits: Int = 2
    ) -> String {
        let normalizedInput = input
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "−", with: "-")

        var isNegative = false
        var integerDigits = ""
        var fractionDigits = ""
        var hasDecimalSeparator = false

        for character in normalizedInput {
            if character == "-", allowsNegative, integerDigits.isEmpty, fractionDigits.isEmpty, !hasDecimalSeparator {
                isNegative = true
                continue
            }

            if character == "," || character == "." {
                guard !hasDecimalSeparator, maximumFractionDigits > 0 else { continue }
                hasDecimalSeparator = true
                continue
            }

            guard character.isNumber else { continue }

            if hasDecimalSeparator {
                if fractionDigits.count < maximumFractionDigits {
                    fractionDigits.append(character)
                }
            } else {
                integerDigits.append(character)
            }
        }

        if integerDigits.isEmpty, !hasDecimalSeparator {
            return isNegative ? "-" : ""
        }

        integerDigits = normalizedIntegerDigits(integerDigits)
        let groupedInteger = grouped(integerDigits.isEmpty ? "0" : integerDigits)
        let sign = isNegative ? "-" : ""

        guard hasDecimalSeparator else {
            return "\(sign)\(groupedInteger)"
        }

        return "\(sign)\(groupedInteger),\(fractionDigits)"
    }

    static func value(from input: String, allowsNegative: Bool = true) -> Double {
        let sanitizedInput = sanitized(input, allowsNegative: allowsNegative)
        let normalized = sanitizedInput
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard normalized != "-", !normalized.isEmpty else { return 0 }
        let value = Double(normalized) ?? 0
        return allowsNegative ? value : max(0, value)
    }

    private static func normalizedIntegerDigits(_ digits: String) -> String {
        let trimmed = digits.drop(while: { $0 == "0" })
        return trimmed.isEmpty ? "0" : String(trimmed)
    }

    private static func grouped(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }

        var groups: [String] = []
        var endIndex = digits.endIndex

        while endIndex > digits.startIndex {
            let startIndex = digits.index(endIndex, offsetBy: -3, limitedBy: digits.startIndex)
                ?? digits.startIndex
            groups.append(String(digits[startIndex..<endIndex]))
            endIndex = startIndex
        }

        return groups.reversed().joined(separator: " ")
    }
}
