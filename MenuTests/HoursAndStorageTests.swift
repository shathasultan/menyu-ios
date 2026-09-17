import XCTest
@testable import Menu

/// The remaining fixes that are pure enough to pin down without a device: the
/// hours formatter, the storage-path reader behind image deletion, and the
/// user-facing error mapping.
final class HoursAndStorageTests: XCTestCase {

    // MARK: - Hours

    func testHoursAlwaysWriteLatinDigits() {
        // The formatter used to have no locale, so on a phone set to Arabic it
        // wrote "٠٩:٠٠" into the database. Reading it back, `Int("٠٩")` is nil,
        // so `isOpenNow` returned nil and the venue showed neither open nor
        // closed for every customer, permanently.
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 17
        components.hour = 9; components.minute = 5
        let date = Calendar.current.date(from: components)!

        let text = Hours.text(date)
        XCTAssertEqual(text, "09:05")
        XCTAssertTrue(text.allSatisfy { $0.isASCII })
    }

    func testHoursRoundTrip() {
        let restored = Hours.date("18:30", defaultHour: 9)
        XCTAssertEqual(Hours.text(restored), "18:30")
    }

    func testHoursFallBackToTheDefaultHour() {
        XCTAssertEqual(Hours.text(Hours.date(nil, defaultHour: 9)), "09:00")
        XCTAssertEqual(Hours.text(Hours.date("not a time", defaultHour: 23)), "23:00")
    }

    func testStoredHoursDriveOpenNow() {
        // Proves the two halves agree: what `Hours.text` writes is what
        // `isOpenNow` can parse.
        let alwaysOpen = Self.restaurant(opensAt: "00:00", closesAt: "23:59")
        XCTAssertEqual(alwaysOpen.isOpenNow, true)

        let arabicDigits = Self.restaurant(opensAt: "٠٠:٠٠", closesAt: "٢٣:٥٩")
        XCTAssertNil(arabicDigits.isOpenNow, "Arabic-Indic digits are exactly the state the formatter fix prevents")
    }

    // MARK: - Storage paths

    func testStoragePathIsReadFromThePublicURL() {
        let url = "https://abc.supabase.co/storage/v1/object/public/menu-images/11111111-1111-1111-1111-111111111111/logo-2222.jpg"
        XCTAssertEqual(AppStore.storagePath(from: url),
                       "11111111-1111-1111-1111-111111111111/logo-2222.jpg")
    }

    func testStoragePathDropsAQueryString() {
        let url = "https://abc.supabase.co/storage/v1/object/public/menu-images/r/logo-1.jpg?token=xyz"
        XCTAssertEqual(AppStore.storagePath(from: url), "r/logo-1.jpg")
    }

    func testStoragePathStillReadsLegacyRootObjects() {
        // Rows written before migration 0008 point at the bucket root. Deletion
        // has to target what the row actually says, not re-derive a convention.
        let url = "https://abc.supabase.co/storage/v1/object/public/menu-images/33333333-3333-3333-3333-333333333333.jpg"
        XCTAssertEqual(AppStore.storagePath(from: url), "33333333-3333-3333-3333-333333333333.jpg")
    }

    func testStoragePathIsNilForNonsense() {
        XCTAssertNil(AppStore.storagePath(from: nil))
        XCTAssertNil(AppStore.storagePath(from: ""))
        XCTAssertNil(AppStore.storagePath(from: "https://example.com/other-bucket/x.jpg"))
        XCTAssertNil(AppStore.storagePath(from: "https://abc.supabase.co/menu-images/"))
    }

    // MARK: - Error text

    @MainActor
    func testErrorsAreTranslatedNotDumped() {
        let store = AppStore(loadOnStart: false)

        let rls = NSError(domain: "PostgREST", code: 42501, userInfo: [
            NSLocalizedDescriptionKey: #"new row violates row-level security policy for table "restaurants""#
        ])
        store.report(rls, fallback: "تعذّر الحفظ.")
        XCTAssertEqual(store.errorMessage, "ليست لديك صلاحية لهذه العملية.")

        let offline = NSError(domain: NSURLErrorDomain, code: -1009, userInfo: [
            NSLocalizedDescriptionKey: "The Internet connection appears to be offline."
        ])
        store.report(offline, fallback: "تعذّر الحفظ.")
        XCTAssertEqual(store.errorMessage, "لا يوجد اتصال بالإنترنت.")
    }

    @MainActor
    func testUnrecognisedErrorsUseTheCallersOwnWording() {
        let store = AppStore(loadOnStart: false)
        let odd = NSError(domain: "X", code: 1, userInfo: [NSLocalizedDescriptionKey: "PGRST116 something internal"])
        store.report(odd, fallback: "تعذّرت إضافة المنتج.")
        // Never the raw backend string.
        XCTAssertEqual(store.errorMessage, "تعذّرت إضافة المنتج.")
    }

    // MARK: - Fixture

    private static func restaurant(opensAt: String?, closesAt: String?) -> Restaurant {
        Restaurant(
            id: UUID(), ownerID: UUID(), name: "Brew", nameAr: "بريو",
            type: .cafe, descriptionEn: "", descriptionAr: "",
            status: .approved, opensAt: opensAt, closesAt: closesAt,
            latitude: nil, longitude: nil, imageURL: nil,
            phone: nil, address: nil, nextCategoryIndex: 0, categories: []
        )
    }
}
