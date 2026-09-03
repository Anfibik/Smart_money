import Foundation

enum AppCurrencyFormatter {
    static func symbol(for currencyCode: String) -> String {
        switch currencyCode {
        case "UAH":
            return "₴"
        case ForeignCurrencyType.usd.rawValue:
            return "$"
        case ForeignCurrencyType.eur.rawValue:
            return "€"
        case ForeignCurrencyType.gbp.rawValue:
            return "£"
        case ForeignCurrencyType.chf.rawValue:
            return "CHF"
        case ForeignCurrencyType.pln.rawValue:
            return "zł"
        case ForeignCurrencyType.cad.rawValue:
            return "C$"
        case ForeignCurrencyType.jpy.rawValue:
            return "¥"
        case ForeignCurrencyType.cny.rawValue:
            return "CN¥"
        case ForeignCurrencyType.rub.rawValue:
            return "₽"
        default:
            return currencyCode
        }
    }

    static func string(_ value: Double, currencyCode: String) -> String {
        if currencyCode == "UAH" {
            return "\(decimalString(value)) ₴"
        }
        if ForeignCurrencyType(rawValue: currencyCode) != nil {
            return "\(decimalString(value)) \(symbol(for: currencyCode))"
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
