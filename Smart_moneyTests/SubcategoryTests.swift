import XCTest

final class SubcategoryTests: XCTestCase {
    func testLegacySystemSubcategoryInfersSystemKeyFromName() throws {
        let data = """
        {
          "id": "\(UUID().uuidString)",
          "name": "Жилье",
          "isSystem": true,
          "percentage": 30,
          "priority": 3,
          "spentAmount": 0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(Subcategory.self, from: data)

        XCTAssertEqual(decoded.systemKey, .housing)
        XCTAssertEqual(decoded.iconName, SystemSubcategoryKey.housing.defaultIconName)
    }
}
