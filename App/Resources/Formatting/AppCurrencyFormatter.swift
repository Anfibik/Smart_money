import Foundation

enum AppCurrencyFormatter {
    static func string(_ value: Double, currencyCode: String) -> String {
        if currencyCode == "UAH" {
            return "\(decimalString(value)) ₴"
        }

        return value.formatted(.currency(code: currencyCode))
    }

    private static func decimalString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = ","
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
