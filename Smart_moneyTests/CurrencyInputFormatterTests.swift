import XCTest

final class CurrencyInputFormatterTests: XCTestCase {
    func testSanitizedInputGroupsThousandsAndUsesComma() {
        XCTAssertEqual(
            CurrencyInputFormatter.sanitized("1234567.89"),
            "1 234 567,89"
        )
    }

    func testSanitizedInputLimitsFractionAndRemovesInvalidCharacters() {
        XCTAssertEqual(
            CurrencyInputFormatter.sanitized("12a 345,678 ₴"),
            "12 345,67"
        )
    }

    func testSanitizedInputSupportsFourFractionDigitsForExchangeRate() {
        XCTAssertEqual(
            CurrencyInputFormatter.sanitized(
                "41.12345",
                maximumFractionDigits: 4
            ),
            "41,1234"
        )
    }

    func testNegativeValueIsAvailableOnlyWhenAllowed() {
        XCTAssertEqual(
            CurrencyInputFormatter.sanitized("-20000", allowsNegative: true),
            "-20 000"
        )
        XCTAssertEqual(
            CurrencyInputFormatter.sanitized("-20000", allowsNegative: false),
            "20 000"
        )
    }

    func testValueParsesFormattedInput() {
        XCTAssertEqual(
            CurrencyInputFormatter.value(from: "1 234 567,89"),
            1_234_567.89,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CurrencyInputFormatter.value(from: "-500", allowsNegative: false),
            500,
            accuracy: 0.0001
        )
    }
}
