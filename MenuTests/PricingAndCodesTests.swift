import XCTest
@testable import Menu

/// Covers the pure logic behind four bugs that reached customers: prices
/// truncated to whole riyals, Arabic-Indic prices read as zero, Arabic search
/// missing obvious matches, and the "auto code" preview promising a code the
/// database would not assign.
final class PricingAndCodesTests: XCTestCase {

    // MARK: - Money

    func testPriceKeepsHalalas() {
        XCTAssertEqual(Money.text(14.5, language: .arabic), "14.5 ر.س")
        XCTAssertEqual(Money.text(14.25, language: .english), "SAR 14.25")
    }

    func testWholeRiyalsStayWhole() {
        XCTAssertEqual(Money.text(14, language: .arabic), "14 ر.س")
        XCTAssertEqual(Money.text(0, language: .english), "SAR 0")
    }

    func testPriceUsesLatinDigitsInBothLanguages() {
        // The formatter is pinned to en_US_POSIX: an Arabic device locale would
        // otherwise render ١٢٣٤ and the vendor's own code chips wouldn't match.
        // POSIX also groups nothing, so the number reads plainly.
        XCTAssertEqual(Money.text(1234.5, language: .arabic), "1234.5 ر.س")

        // The point of the test, stated directly: no Arabic-Indic digits, ever.
        let digits = Money.text(1234.5, language: .arabic).filter(\.isNumber)
        XCTAssertTrue(digits.allSatisfy { $0.isASCII }, "قيمة بأرقام غير لاتينية: \(digits)")
    }

    func testParseAcceptsArabicIndicDigits() {
        XCTAssertEqual(Money.parse("١٤"), 14)
        XCTAssertEqual(Money.parse("١٤٫٥"), 14.5)
        XCTAssertEqual(Money.parse("٠"), 0)
    }

    func testParseAcceptsLatinDigitsAndSeparators() {
        XCTAssertEqual(Money.parse("14"), 14)
        XCTAssertEqual(Money.parse("14.5"), 14.5)
        XCTAssertEqual(Money.parse("14,5"), 14.5)
        XCTAssertEqual(Money.parse(" 14.5 "), 14.5)
    }

    func testParseRejectsNonNumbers() {
        XCTAssertNil(Money.parse(""))
        XCTAssertNil(Money.parse("لاتيه"))
    }

    // MARK: - Arabic folding

    func testFoldingUnifiesHamzaAndTaMarbuta() {
        XCTAssertEqual("إسبريسو".searchFolded, "اسبريسو".searchFolded)
        XCTAssertEqual("أسبريسو".searchFolded, "اسبريسو".searchFolded)
        XCTAssertEqual("شوكولاته".searchFolded, "شوكولاتة".searchFolded)
        XCTAssertEqual("مقهى".searchFolded, "مقهي".searchFolded)
    }

    @MainActor
    func testSearchFindsAHamzaVariant() {
        let store = AppStore(loadOnStart: false)
        store.restaurants = [Self.cafe]
        // Typed without the hamza — the old literal `contains` returned nothing.
        XCTAssertEqual(store.search(query: "اسبريسو").map(\.item.code), ["A01"])
    }

    @MainActor
    func testSearchStillMatchesCodeExactlyOnly() {
        let store = AppStore(loadOnStart: false)
        store.restaurants = [Self.cafe]
        XCTAssertEqual(store.search(query: "a01").map(\.item.code), ["A01"])
        XCTAssertTrue(store.search(query: "A0").isEmpty)
    }

    // MARK: - Code previews

    func testNextCodeComesFromTheCounterNotTheItemCount() {
        // Two items were added and one deleted: the counter is at 3, so the next
        // code is A03. Counting the remaining items would promise A02, which is
        // already taken.
        let category = MenuCategory(
            id: UUID(), letter: "A", name: "Hot", nameAr: "ساخن", nextItemNumber: 3,
            items: [MenuItem(id: UUID(), code: "A02", name: "Latte", nameAr: "لاتيه", price: 14, isAvailable: true)]
        )
        XCTAssertEqual(category.nextItemCode, "A03")
    }

    func testNextCategoryLetterComesFromTheCounter() {
        XCTAssertEqual(Self.makeRestaurant(nextCategoryIndex: 0).nextCategoryLetter, "A")
        XCTAssertEqual(Self.makeRestaurant(nextCategoryIndex: 2).nextCategoryLetter, "C")
        XCTAssertEqual(Self.makeRestaurant(nextCategoryIndex: 25).nextCategoryLetter, "Z")
        XCTAssertNil(Self.makeRestaurant(nextCategoryIndex: 26).nextCategoryLetter)
    }

    // MARK: - Publish state

    func testIsPublishedIsDerivedFromStatus() {
        XCTAssertTrue(Self.makeRestaurant(status: .approved).isPublished)
        XCTAssertFalse(Self.makeRestaurant(status: .pending).isPublished)
        XCTAssertFalse(Self.makeRestaurant(status: .rejected).isPublished)
    }

    // MARK: - Placeholder tint

    func testPlaceholderTintIsStableForTheSameID() {
        // Keyed off `hashValue` this held within one process but changed on the
        // next launch, because Swift seeds hashing randomly per process.
        let id = UUID(uuidString: "6E7E3E2A-1B4C-4D5E-8F90-A1B2C3D4E5F6")!
        let first = Self.makeRestaurant(id: id).placeholderTint
        let second = Self.makeRestaurant(id: id).placeholderTint
        XCTAssertEqual(first.bg, second.bg)
        XCTAssertEqual(first.fg, second.fg)
    }

    // MARK: - Hours

    func testOpenNowUsesTheVenueTimezoneNotTheDevice() {
        XCTAssertEqual(Restaurant.venueCalendar.timeZone.identifier, "Asia/Riyadh")
    }

    func testOvernightHoursSpanMidnight() {
        let late = Self.makeRestaurant(opensAt: "18:00", closesAt: "02:00")
        XCTAssertNotNil(late.isOpenNow)
        XCTAssertNil(Self.makeRestaurant(opensAt: nil, closesAt: nil).isOpenNow)
    }

    // MARK: - Fixtures

    private static var cafe: Restaurant {
        makeRestaurant(categories: [
            MenuCategory(id: UUID(), letter: "A", name: "Hot Drinks", nameAr: "مشروبات ساخنة", nextItemNumber: 2, items: [
                MenuItem(id: UUID(), code: "A01", name: "Espresso", nameAr: "إسبريسو", price: 10.5, isAvailable: true),
            ]),
        ])
    }

    private static func makeRestaurant(
        id: UUID = UUID(),
        status: RestaurantStatus = .approved,
        nextCategoryIndex: Int = 0,
        opensAt: String? = "09:00",
        closesAt: String? = "23:00",
        categories: [MenuCategory] = []
    ) -> Restaurant {
        Restaurant(
            id: id, ownerID: UUID(), name: "Brew Cafe", nameAr: "بريو كافيه",
            type: .cafe, descriptionEn: "", descriptionAr: "",
            status: status, opensAt: opensAt, closesAt: closesAt,
            latitude: nil, longitude: nil, imageURL: nil,
            phone: nil, address: nil, nextCategoryIndex: nextCategoryIndex,
            categories: categories
        )
    }
}
