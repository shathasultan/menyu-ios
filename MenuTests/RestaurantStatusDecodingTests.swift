import XCTest
@testable import Menu

/// `status` is what lets the owner's screens tell a declined application from
/// one still in the review queue — both are unpublished, and `isPublished`
/// alone can't separate them.
final class RestaurantStatusDecodingTests: XCTestCase {

    private func decode(statusField: String?, isPublished: Bool) throws -> Restaurant {
        let statusJSON = statusField.map { "\"status\": \"\($0)\"," } ?? ""
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "owner_id": "22222222-2222-2222-2222-222222222222",
          "name": "Brew Cafe",
          "name_ar": "بريو كافيه",
          "type": "cafe",
          "description_en": "",
          "description_ar": "",
          "next_category_index": 0,
          "is_published": \(isPublished),
          \(statusJSON)
          "menu_categories": []
        }
        """
        let row = try JSONDecoder().decode(RestaurantRow.self, from: Data(json.utf8))
        return row.toRestaurant()
    }

    func testDecodesEachStatus() throws {
        XCTAssertEqual(try decode(statusField: "pending", isPublished: false).status, .pending)
        XCTAssertEqual(try decode(statusField: "approved", isPublished: true).status, .approved)
        XCTAssertEqual(try decode(statusField: "rejected", isPublished: false).status, .rejected)
    }

    func testRejectedIsDistinctFromPendingEvenThoughBothAreUnpublished() throws {
        let rejected = try decode(statusField: "rejected", isPublished: false)
        let pending = try decode(statusField: "pending", isPublished: false)
        XCTAssertFalse(rejected.isPublished)
        XCTAssertFalse(pending.isPublished)
        XCTAssertNotEqual(rejected.status, pending.status)
    }

    func testMissingStatusFallsBackToThePublishedFlag() throws {
        // Rows written before migration 0006 added the column, and any response
        // where it wasn't selected, still have to decode rather than throw.
        XCTAssertEqual(try decode(statusField: nil, isPublished: true).status, .approved)
        XCTAssertEqual(try decode(statusField: nil, isPublished: false).status, .pending)
    }

    func testUnknownStatusFallsBackRatherThanFailingToDecode() throws {
        // A value added to the DB's check constraint before the app ships must
        // not take the whole restaurant list down with it.
        XCTAssertEqual(try decode(statusField: "archived", isPublished: false).status, .pending)
    }
}
