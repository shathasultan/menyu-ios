import XCTest
@testable import Menu

/// `AppStore.letterFromIndex` is the whole product-code scheme: the category's
/// letter is the prefix every item code inherits, and a code is the one string
/// a customer types to find a product. These assertions exist because the
/// original implementation gave up past Z and returned a literal "?".
final class CategoryLetterTests: XCTestCase {

    func testFirstTwentySixAreUnchanged() {
        // Restaurants already live have codes minted by the old scheme — the
        // first 26 indices must keep meaning exactly what they meant before.
        XCTAssertEqual(AppStore.letterFromIndex(0), "A")
        XCTAssertEqual(AppStore.letterFromIndex(1), "B")
        XCTAssertEqual(AppStore.letterFromIndex(25), "Z")
    }

    func testContinuesPastZInsteadOfCollapsing() {
        // Previously every index ≥ 26 returned "?", so the 27th and 28th
        // categories both minted "?01" — two different products in one
        // restaurant answering to the same code.
        XCTAssertEqual(AppStore.letterFromIndex(26), "AA")
        XCTAssertEqual(AppStore.letterFromIndex(27), "AB")
        XCTAssertEqual(AppStore.letterFromIndex(51), "AZ")
        XCTAssertEqual(AppStore.letterFromIndex(52), "BA")
        XCTAssertEqual(AppStore.letterFromIndex(701), "ZZ")
        XCTAssertEqual(AppStore.letterFromIndex(702), "AAA")
    }

    func testNoTwoIndicesShareALetter() {
        let letters = (0..<1000).map(AppStore.letterFromIndex)
        XCTAssertEqual(Set(letters).count, letters.count, "Category letters must be unique — codes are built from them.")
    }

    func testLettersAreAlwaysUppercaseASCII() {
        for index in 0..<1000 {
            let letter = AppStore.letterFromIndex(index)
            XCTAssertFalse(letter.isEmpty)
            XCTAssertTrue(letter.allSatisfy { $0.isASCII && $0.isUppercase }, "Unexpected letter \(letter) at \(index)")
        }
    }

    func testNegativeIndexFallsBackToFirstLetter() {
        // Can't happen through the RPC, which only ever hands back a claimed
        // counter value — this just pins the guard's behaviour.
        XCTAssertEqual(AppStore.letterFromIndex(-1), "A")
    }
}
