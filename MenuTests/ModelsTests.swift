import XCTest
@testable import Menu

final class ModelsTests: XCTestCase {

    // MARK: - RestaurantType

    func testRestaurantTypeArabicLabels() {
        XCTAssertEqual(RestaurantType.restaurant.label(.arabic), "مطعم")
        XCTAssertEqual(RestaurantType.cafe.label(.arabic), "مقهى")
        XCTAssertEqual(RestaurantType.kiosk.label(.arabic), "كشك")
        XCTAssertEqual(RestaurantType.foodTruck.label(.arabic), "عربة طعام")
    }

    func testRestaurantTypeEnglishLabels() {
        XCTAssertEqual(RestaurantType.restaurant.label(.english), "Restaurant")
        XCTAssertEqual(RestaurantType.cafe.label(.english), "Café")
        XCTAssertEqual(RestaurantType.kiosk.label(.english), "Kiosk")
        XCTAssertEqual(RestaurantType.foodTruck.label(.english), "Food Truck")
    }

    func testRestaurantTypeRawValuesMatchDatabaseColumn() {
        // These raw values are written to/read from the "type" column in
        // Supabase — changing them would silently break existing rows.
        XCTAssertEqual(RestaurantType.restaurant.rawValue, "restaurant")
        XCTAssertEqual(RestaurantType.cafe.rawValue, "cafe")
        XCTAssertEqual(RestaurantType.kiosk.rawValue, "kiosk")
        XCTAssertEqual(RestaurantType.foodTruck.rawValue, "food_truck")
    }

    func testRestaurantTypeHasAnIconForEveryCase() {
        for type in RestaurantType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) has no SF Symbol icon")
        }
    }

    // MARK: - MenuItem

    func testMenuItemDisplayNamePicksLanguage() {
        let item = MenuItem(id: UUID(), code: "A01", name: "Latte", nameAr: "لاتيه", price: 14, isAvailable: true)
        XCTAssertEqual(item.displayName(.arabic), "لاتيه")
        XCTAssertEqual(item.displayName(.english), "Latte")
    }

    // MARK: - MenuCategory

    func testMenuCategoryDisplayNamePicksLanguage() {
        let category = MenuCategory(id: UUID(), letter: "A", name: "Hot Drinks", nameAr: "مشروبات ساخنة", items: [])
        XCTAssertEqual(category.displayName(.arabic), "مشروبات ساخنة")
        XCTAssertEqual(category.displayName(.english), "Hot Drinks")
    }

    // MARK: - Restaurant

    private func makeRestaurant(categories: [MenuCategory] = [], latitude: Double? = nil, longitude: Double? = nil) -> Restaurant {
        Restaurant(
            id: UUID(), ownerID: UUID(), name: "Brew Cafe", nameAr: "بريو كافيه",
            type: .cafe, descriptionEn: "Specialty coffee", descriptionAr: "قهوة مختصة",
            isPublished: true, opensAt: "09:00", closesAt: "23:00",
            latitude: latitude, longitude: longitude, imageURL: nil,
            categories: categories
        )
    }

    func testRestaurantDisplayNameAndDescriptionPickLanguage() {
        let r = makeRestaurant()
        XCTAssertEqual(r.displayName(.arabic), "بريو كافيه")
        XCTAssertEqual(r.displayName(.english), "Brew Cafe")
        XCTAssertEqual(r.displayDescription(.arabic), "قهوة مختصة")
        XCTAssertEqual(r.displayDescription(.english), "Specialty coffee")
    }

    func testRestaurantHasLocationRequiresBothCoordinates() {
        XCTAssertFalse(makeRestaurant().hasLocation)
        XCTAssertFalse(makeRestaurant(latitude: 24.7136, longitude: nil).hasLocation)
        XCTAssertFalse(makeRestaurant(latitude: nil, longitude: 46.6753).hasLocation)
        XCTAssertTrue(makeRestaurant(latitude: 24.7136, longitude: 46.6753).hasLocation)
    }

    func testRestaurantAllItemsFlattensEveryCategoryInOrder() {
        let hot = MenuCategory(id: UUID(), letter: "A", name: "Hot", nameAr: "ساخن", items: [
            MenuItem(id: UUID(), code: "A01", name: "Espresso", nameAr: "اسبريسو", price: 10, isAvailable: true),
            MenuItem(id: UUID(), code: "A02", name: "Latte", nameAr: "لاتيه", price: 14, isAvailable: true),
        ])
        let cold = MenuCategory(id: UUID(), letter: "B", name: "Cold", nameAr: "بارد", items: [
            MenuItem(id: UUID(), code: "B01", name: "Iced Tea", nameAr: "شاي مثلج", price: 12, isAvailable: false),
        ])
        let r = makeRestaurant(categories: [hot, cold])

        XCTAssertEqual(r.allItems.map(\.code), ["A01", "A02", "B01"])
    }

    func testRestaurantAllItemsIsEmptyWithNoCategories() {
        XCTAssertTrue(makeRestaurant().allItems.isEmpty)
    }
}
