import XCTest
@testable import Menu

/// Exercises `AppStore.search`, which is pure once `restaurants` is populated —
/// no network involved in the assertions themselves. Constructing `AppStore(loadOnStart: false)`
/// does kick off its usual background session-check/load calls (same as at app
/// launch); that's a real network side effect of this suite, not something
/// these tests wait on or depend on.
@MainActor
final class AppStoreSearchTests: XCTestCase {

    private func makeStore(with restaurants: [Restaurant]) -> AppStore {
        let store = AppStore(loadOnStart: false)
        store.restaurants = restaurants
        return store
    }

    private func sampleRestaurant() -> Restaurant {
        let hot = MenuCategory(id: UUID(), letter: "A", name: "Hot Drinks", nameAr: "مشروبات ساخنة", nextItemNumber: 1, items: [
            MenuItem(id: UUID(), code: "A01", name: "Espresso", nameAr: "اسبريسو", price: 10, isAvailable: true),
            MenuItem(id: UUID(), code: "A02", name: "Latte", nameAr: "لاتيه", price: 14, isAvailable: true),
        ])
        return Restaurant(
            id: UUID(), ownerID: UUID(), name: "Brew Cafe", nameAr: "بريو كافيه",
            type: .cafe, descriptionEn: "", descriptionAr: "",
            status: .approved, opensAt: nil, closesAt: nil,
            latitude: nil, longitude: nil, imageURL: nil,
            phone: nil, address: nil, nextCategoryIndex: 1,
            categories: [hot]
        )
    }

    func testEmptyQueryReturnsNoResults() {
        let store = makeStore(with: [sampleRestaurant()])
        XCTAssertTrue(store.search(query: "").isEmpty)
        XCTAssertTrue(store.search(query: "   ").isEmpty)
    }

    func testSearchMatchesExactCodeCaseInsensitively() {
        let store = makeStore(with: [sampleRestaurant()])
        let results = store.search(query: "a01")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.item.code, "A01")
    }

    func testSearchDoesNotMatchPartialCode() {
        // Code matching is exact-equality by design (a code is an identifier,
        // not free text) — "A0" must not match "A01".
        let store = makeStore(with: [sampleRestaurant()])
        XCTAssertTrue(store.search(query: "A0").isEmpty)
    }

    func testSearchMatchesEnglishNameSubstring() {
        let store = makeStore(with: [sampleRestaurant()])
        let results = store.search(query: "lat")
        XCTAssertEqual(results.map(\.item.code), ["A02"])
    }

    func testSearchMatchesArabicNameSubstring() {
        let store = makeStore(with: [sampleRestaurant()])
        let results = store.search(query: "لاتيه")
        XCTAssertEqual(results.map(\.item.code), ["A02"])
    }

    func testSearchAcrossMultipleRestaurants() {
        let second = Restaurant(
            id: UUID(), ownerID: UUID(), name: "Burger House", nameAr: "برجر هاوس",
            type: .restaurant, descriptionEn: "", descriptionAr: "",
            status: .approved, opensAt: nil, closesAt: nil,
            latitude: nil, longitude: nil, imageURL: nil,
            phone: nil, address: nil, nextCategoryIndex: 1,
            categories: [
                MenuCategory(id: UUID(), letter: "A", name: "Burgers", nameAr: "برجر", nextItemNumber: 1, items: [
                    MenuItem(id: UUID(), code: "A01", name: "Classic Burger", nameAr: "برجر كلاسيك", price: 22, isAvailable: true),
                ]),
            ]
        )
        let store = makeStore(with: [sampleRestaurant(), second])

        // Both restaurants independently generate their own "A01" — searching by
        // that code should surface both, matching the spec's per-restaurant code
        // scoping (codes are only unique within a single restaurant).
        let results = store.search(query: "A01")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(Set(results.map { $0.restaurant.name }), ["Brew Cafe", "Burger House"])
    }
}
