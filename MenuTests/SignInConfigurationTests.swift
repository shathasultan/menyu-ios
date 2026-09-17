import XCTest
import GoogleSignIn
@testable import Menu

/// Google sign-in fails at runtime for exactly three boring reasons: a missing
/// client id, a URL scheme that isn't the reversed client id, or no handler for
/// the callback URL. None of them show up at compile time — the button simply
/// does nothing, or the browser never comes back.
///
/// The test target is hosted by the app (`TEST_HOST` in the project), so
/// `Bundle.main` here is the real `Menu.app` bundle and these assertions read
/// the same Info.plist the app runs with.
final class SignInConfigurationTests: XCTestCase {

    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    // MARK: - Google

    func testGoogleClientIDIsPresentAndWellFormed() throws {
        let clientID = try XCTUnwrap(info["GIDClientID"] as? String, "GIDClientID missing from Info.plist")
        XCTAssertTrue(clientID.hasSuffix(".apps.googleusercontent.com"),
                      "GIDClientID should end in .apps.googleusercontent.com, got \(clientID)")
    }

    func testURLSchemeIsTheReversedClientID() throws {
        let clientID = try XCTUnwrap(info["GIDClientID"] as? String)
        // "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
        let prefix = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        let expected = "com.googleusercontent.apps.\(prefix)"

        let urlTypes = (info["CFBundleURLTypes"] as? [[String: Any]]) ?? []
        let schemes = urlTypes.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }

        XCTAssertTrue(schemes.contains(expected),
                      "Google's callback needs the reversed client id as a URL scheme. Expected \(expected), found \(schemes)")
    }

    func testGoogleSignInIsConfiguredAtLaunch() throws {
        // MenuApp.init assigns this. If it were missing, `signIn(withPresenting:)`
        // throws before any UI appears.
        let configuration = try XCTUnwrap(GIDSignIn.sharedInstance.configuration,
                                          "GIDSignIn.sharedInstance.configuration was never set — check MenuApp.init")
        XCTAssertEqual(configuration.clientID, info["GIDClientID"] as? String)
    }

    // MARK: - Apple

    func testAppleSignInEntitlementIsDeclared() throws {
        // Guideline 4.8: offering Google means Apple has to be offered too, and
        // the button does nothing without this entitlement.
        let path = try XCTUnwrap(Bundle(for: Self.self).path(forResource: "Menu", ofType: "entitlements")
                                 ?? Bundle.main.path(forResource: "Menu", ofType: "entitlements"),
                                 "Menu.entitlements not readable from the test bundle — verify manually in Signing & Capabilities")
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        XCTAssertTrue(contents.contains("com.apple.developer.applesignin"))
    }

    func testAppleNonceIsFreshAndHashed() async {
        let store = await AppStore(loadOnStart: false)
        let first = await store.makeAppleNonce()
        let second = await store.makeAppleNonce()

        // SHA256 hex — what ASAuthorizationAppleIDRequest.nonce expects.
        XCTAssertEqual(first.count, 64)
        XCTAssertTrue(first.allSatisfy { $0.isHexDigit })
        // A reused nonce is a replayable sign-in.
        XCTAssertNotEqual(first, second)
    }

    // MARK: - Location

    func testLocationUsageDescriptionExists() {
        // Without it, the first `requestWhenInUseAuthorization()` crashes the app.
        let key = info["NSLocationWhenInUseUsageDescription"] as? String
        XCTAssertFalse((key ?? "").isEmpty, "NSLocationWhenInUseUsageDescription missing from Info.plist")
    }

    // MARK: - Failure messages

    @MainActor
    func testCancellationIsNotReportedAsAFailure() {
        let store = AppStore(loadOnStart: false)
        let googleCancel = NSError(domain: "com.google.GIDSignIn", code: -5)
        XCTAssertNil(store.signInFailureText(googleCancel, arabic: true))
    }

    @MainActor
    func testMissingAccountPointsAtGoogleRatherThanThePassword() {
        let store = AppStore(loadOnStart: false)
        let error = NSError(domain: "Auth", code: 400, userInfo: [
            NSLocalizedDescriptionKey: "Invalid login credentials"
        ])
        let text = try? XCTUnwrap(store.signInFailureText(error, arabic: true))
        // The old wording blamed the password even when no such account existed,
        // or when the account was a Google one with no password at all.
        XCTAssertTrue((text ?? "").contains("قوقل"))
    }

    @MainActor
    func testUnconfirmedEmailSaysSo() {
        let store = AppStore(loadOnStart: false)
        let error = NSError(domain: "Auth", code: 400, userInfo: [
            NSLocalizedDescriptionKey: "Email not confirmed"
        ])
        XCTAssertEqual(store.signInFailureText(error, arabic: true),
                       "الحساب موجود لكن البريد غير مؤكَّد. أكّديه من لوحة Supabase أو من رسالة التأكيد.")
    }

    @MainActor
    func testUnregisteredClientIDIsNamed() {
        let store = AppStore(loadOnStart: false)
        let error = NSError(domain: "Auth", code: 400, userInfo: [
            NSLocalizedDescriptionKey: "Invalid claim: missing sub claim, bad audience in client_id"
        ])
        XCTAssertTrue((store.signInFailureText(error, arabic: true) ?? "").contains("Authorized Client IDs"))
    }

    @MainActor
    func testOfflineIsNotBlamedOnCredentials() {
        let store = AppStore(loadOnStart: false)
        let error = NSError(domain: NSURLErrorDomain, code: -1009)
        XCTAssertEqual(store.signInFailureText(error, arabic: true), "لا يوجد اتصال بالإنترنت.")
    }

    // MARK: - Branding

    func testGoogleOfficialMarkIsBundled() {
        // Not a crash, a rejection: Google's branding guidelines require their
        // own mark on the button. Add the "G" from Google's branding kit to
        // Assets.xcassets as an image set named "GoogleG".
        XCTAssertTrue(GoogleGlyph.hasOfficialMark,
                      "Add Google's official 'G' to Assets.xcassets as \"GoogleG\" before submitting.")
    }
}
