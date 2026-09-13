import XCTest
@testable import Menu

/// AppStore persists favorites to UserDefaults.standard under a fixed key —
/// the same store a real device/simulator uses. To avoid clobbering whatever
/// favorites exist there from manual testing, each test snapshots and
/// restores that key.
@MainActor
final class FavoritesPersistenceTests: XCTestCase {
    private static let key = "menu.favoriteItemIDs.v1"
    private var previousValue: [String]?

    override func setUp() {
        super.setUp()
        previousValue = UserDefaults.standard.stringArray(forKey: Self.key)
        UserDefaults.standard.removeObject(forKey: Self.key)
    }

    override func tearDown() {
        if let previousValue {
            UserDefaults.standard.set(previousValue, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
        super.tearDown()
    }

    private func sampleItem(code: String = "A01") -> MenuItem {
        MenuItem(id: UUID(), code: code, name: "Latte", nameAr: "لاتيه", price: 14, isAvailable: true)
    }

    func testNewItemStartsNotFavorited() {
        let store = AppStore()
        XCTAssertFalse(store.isFavorite(sampleItem()))
    }

    func testToggleFavoriteAddsThenRemoves() {
        let store = AppStore()
        let item = sampleItem()

        store.toggleFavorite(item)
        XCTAssertTrue(store.isFavorite(item))

        store.toggleFavorite(item)
        XCTAssertFalse(store.isFavorite(item))
    }

    func testFavoriteSurvivesAFreshAppStoreInstance() {
        let item = sampleItem()

        let firstLaunch = AppStore()
        firstLaunch.toggleFavorite(item)
        XCTAssertTrue(firstLaunch.isFavorite(item))

        // Simulates relaunching the app: a brand new AppStore should load the
        // same favorite back from UserDefaults instead of starting empty.
        let secondLaunch = AppStore()
        XCTAssertTrue(secondLaunch.isFavorite(item))
    }
}
