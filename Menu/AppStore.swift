import SwiftUI
import Supabase
import PostgREST
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@Observable
@MainActor
final class AppStore {
    var restaurants: [Restaurant] = []
    var myRestaurants: [Restaurant] = []
    var favoriteIDs: Set<UUID> = [] {
        didSet { persistFavorites() }
    }
    var language: Language = .arabic
    var isLoading = false
    var errorMessage: String? = nil
    var currentUserID: UUID? = nil
    var currentUserEmail: String? = nil
    var pendingRestaurants: [Restaurant] = []
    /// The restaurant a vendor is currently managing — set from AccountView's
    /// restaurant list, read by OwnerDashboardView. Shared here so the two
    /// screens (now separate tabs) stay in sync.
    var selectedRestaurantID: UUID? = nil
    /// Set once when RoleGateView's "I'm a vendor" choice routes straight into
    /// sign-in — lets AccountView skip its own VendorIntentGateView so the
    /// choice isn't asked twice back to back. Consumed (reset to false) on read.
    var skipVendorGateOnce = false

    var isAuthenticated: Bool { currentUserID != nil }

    /// Hardcoded reviewers. The second address exists so reviewers can try the
    /// admin role without being handed the owner's personal account; it is
    /// granted the same two policies in migration 0007.
    /// Move to a real roles table if a third admin is ever needed.
    private static let adminEmails: Set<String> = [
        "shathasultann9@gmail.com",
        "demo.admin@menyu.sa",
    ]
    var isAdmin: Bool {
        guard let email = currentUserEmail else { return false }
        return Self.adminEmails.contains(email)
    }

    private static let favoritesDefaultsKey = "menu.favoriteItemIDs.v1"

    init() {
        favoriteIDs = Self.loadPersistedFavorites()
        Task {
            await checkSession()
            await loadRestaurants()
        }
    }

    private static func loadPersistedFavorites() -> Set<UUID> {
        let raw = UserDefaults.standard.stringArray(forKey: favoritesDefaultsKey) ?? []
        return Set(raw.compactMap(UUID.init))
    }

    private func persistFavorites() {
        UserDefaults.standard.set(favoriteIDs.map(\.uuidString), forKey: Self.favoritesDefaultsKey)
    }

    // MARK: - Load Public Restaurants

    func loadRestaurants() async {
        isLoading = true
        errorMessage = nil
        do {
            let rows: [RestaurantRow] = try await supabase
                .from("restaurants")
                .select("*, menu_categories(*, menu_items(*))")
                .eq("is_published", value: true)
                .order("created_at")
                .execute()
                .value
            restaurants = rows.map { $0.toRestaurant() }
            if isAuthenticated { await loadMyRestaurants() }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMyRestaurants() async {
        guard let uid = currentUserID else { return }
        do {
            let rows: [RestaurantRow] = try await supabase
                .from("restaurants")
                .select("*, menu_categories(*, menu_items(*))")
                .eq("owner_id", value: uid.uuidString)
                .order("created_at")
                .execute()
                .value
            myRestaurants = rows.map { $0.toRestaurant() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Owner: Create Restaurant

    @discardableResult
    func createRestaurant(nameEn: String, nameAr: String, type: RestaurantType, descriptionEn: String, descriptionAr: String) async -> UUID? {
        guard let uid = currentUserID else { return nil }
        do {
            struct InsertRestaurant: Encodable {
                let ownerID: UUID
                let name, nameAr, type, descriptionEn, descriptionAr: String
                let isPublished: Bool
                enum CodingKeys: String, CodingKey {
                    case ownerID = "owner_id"
                    case name
                    case nameAr = "name_ar"
                    case type
                    case descriptionEn = "description_en"
                    case descriptionAr = "description_ar"
                    case isPublished = "is_published"
                }
            }
            struct InsertedID: Decodable { let id: UUID }

            let inserted: InsertedID = try await supabase
                .from("restaurants")
                .insert(InsertRestaurant(
                    ownerID: uid,
                    name: nameEn, nameAr: nameAr, type: type.rawValue,
                    descriptionEn: descriptionEn, descriptionAr: descriptionAr,
                    isPublished: false
                ))
                .select("id")
                .single()
                .execute()
                .value

            await loadMyRestaurants()
            return inserted.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Owner: Update Hours / Location / Delete Restaurant

    func updateRestaurantHours(_ restaurantID: UUID, opensAt: String, closesAt: String) async {
        do {
            struct UpdateHours: Encodable {
                let opensAt: String
                let closesAt: String
                enum CodingKeys: String, CodingKey {
                    case opensAt = "opens_at"
                    case closesAt = "closes_at"
                }
            }
            try await supabase
                .from("restaurants")
                .update(UpdateHours(opensAt: opensAt, closesAt: closesAt))
                .eq("id", value: restaurantID.uuidString)
                .execute()
            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRestaurantLocation(_ restaurantID: UUID, latitude: Double, longitude: Double) async {
        do {
            struct UpdateLocation: Encodable {
                let latitude: Double
                let longitude: Double
            }
            try await supabase
                .from("restaurants")
                .update(UpdateLocation(latitude: latitude, longitude: longitude))
                .eq("id", value: restaurantID.uuidString)
                .execute()
            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteRestaurant(_ restaurantID: UUID) async {
        do {
            if let restaurant = myRestaurants.first(where: { $0.id == restaurantID }) {
                var paths = restaurant.allItems.map { "\($0.id.uuidString).jpg" }
                paths.append("restaurant-\(restaurantID.uuidString).jpg")
                try? await supabase.storage.from("menu-images").remove(paths: paths)
            }
            try await supabase.from("restaurants").delete().eq("id", value: restaurantID.uuidString).execute()
            await loadMyRestaurants()
            // Always leave selectedRestaurantID pointing at something real — otherwise
            // OwnerDashboardView is stuck showing its loading spinner forever with
            // nothing left to re-select it.
            if !myRestaurants.contains(where: { $0.id == selectedRestaurantID }) {
                selectedRestaurantID = myRestaurants.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Owner: Item Image

    /// Storage keeps one path per row and re-uploads with `upsert`, so the public
    /// URL never changes when a vendor replaces a picture — and `cacheControl:
    /// 3600` keeps the CDN and the app's own URLCache serving the old bytes for
    /// an hour. SwiftUI never even re-requests: `AsyncImage` is keyed on the URL,
    /// and the URL is byte-identical. Stamping the upload time makes every
    /// replacement its own URL, so the new picture appears at once.
    private static func versioned(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        let stamp = String(Int(Date().timeIntervalSince1970 * 1000))
        components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "v", value: stamp)]
        return components.url?.absoluteString ?? url.absoluteString
    }

    @discardableResult
    func uploadItemImage(_ itemID: UUID, imageData: Data) async -> String? {
        do {
            let path = "\(itemID.uuidString).jpg"
            try await supabase.storage.from("menu-images").upload(
                path, data: imageData,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
            )
            let publicURL = try supabase.storage.from("menu-images").getPublicURL(path: path)
            let imageURL = Self.versioned(publicURL)

            struct UpdateImage: Encodable {
                let imageURL: String
                enum CodingKeys: String, CodingKey { case imageURL = "image_url" }
            }
            try await supabase
                .from("menu_items")
                .update(UpdateImage(imageURL: imageURL))
                .eq("id", value: itemID.uuidString)
                .execute()
            await loadMyRestaurants()
            return imageURL
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func uploadRestaurantImage(_ restaurantID: UUID, imageData: Data) async -> String? {
        do {
            let path = "restaurant-\(restaurantID.uuidString).jpg"
            try await supabase.storage.from("menu-images").upload(
                path, data: imageData,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
            )
            let publicURL = try supabase.storage.from("menu-images").getPublicURL(path: path)
            let imageURL = Self.versioned(publicURL)

            struct UpdateImage: Encodable {
                let imageURL: String
                enum CodingKeys: String, CodingKey { case imageURL = "image_url" }
            }
            try await supabase
                .from("restaurants")
                .update(UpdateImage(imageURL: imageURL))
                .eq("id", value: restaurantID.uuidString)
                .execute()
            await loadMyRestaurants()
            await loadRestaurants()
            return imageURL
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Owner: Delete Category / Item

    func deleteCategory(_ categoryID: UUID) async {
        do {
            let itemPaths = myRestaurants
                .flatMap(\.categories)
                .first(where: { $0.id == categoryID })?
                .items.map { "\($0.id.uuidString).jpg" } ?? []
            if !itemPaths.isEmpty {
                try? await supabase.storage.from("menu-images").remove(paths: itemPaths)
            }
            try await supabase.from("menu_categories").delete().eq("id", value: categoryID.uuidString).execute()
            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ itemID: UUID) async {
        do {
            try? await supabase.storage.from("menu-images").remove(paths: ["\(itemID.uuidString).jpg"])
            try await supabase.from("menu_items").delete().eq("id", value: itemID.uuidString).execute()
            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Admin: Review new restaurants before they go live

    func loadPendingRestaurants() async {
        guard isAdmin else { return }
        do {
            // Filters on `status`, not `is_published` — a rejected restaurant
            // is also unpublished, but must never reappear in this queue
            // (see migration 0006).
            let rows: [RestaurantRow] = try await supabase
                .from("restaurants")
                .select("*, menu_categories(*, menu_items(*))")
                .eq("status", value: "pending")
                .order("created_at")
                .execute()
                .value
            pendingRestaurants = rows.map { $0.toRestaurant() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private struct RestaurantStatusUpdate: Encodable {
        let isPublished: Bool
        let status: String
        enum CodingKeys: String, CodingKey {
            case isPublished = "is_published"
            case status
        }
    }

    func approveRestaurant(_ restaurantID: UUID) async {
        guard isAdmin else { return }
        do {
            try await supabase
                .from("restaurants")
                .update(RestaurantStatusUpdate(isPublished: true, status: "approved"))
                .eq("id", value: restaurantID.uuidString)
                .execute()
            await loadPendingRestaurants()
            await loadRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Permanently declines a pending application — it drops out of the
    /// review queue for good and never reaches customers. There's no
    /// owner-facing "rejected" screen yet; the restaurant just stays
    /// unpublished from the owner's point of view.
    func rejectRestaurant(_ restaurantID: UUID) async {
        guard isAdmin else { return }
        do {
            try await supabase
                .from("restaurants")
                .update(RestaurantStatusUpdate(isPublished: false, status: "rejected"))
                .eq("id", value: restaurantID.uuidString)
                .execute()
            await loadPendingRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Pulls an already-live restaurant back to pending — it disappears from
    /// customer surfaces immediately and returns to the review queue.
    func suspendRestaurant(_ restaurantID: UUID) async {
        guard isAdmin else { return }
        do {
            try await supabase
                .from("restaurants")
                .update(RestaurantStatusUpdate(isPublished: false, status: "pending"))
                .eq("id", value: restaurantID.uuidString)
                .execute()
            await loadPendingRestaurants()
            await loadRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Auth

    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            currentUserID = session.user.id
            currentUserEmail = session.user.email
        } catch {
            currentUserID = nil
            currentUserEmail = nil
        }
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
        await checkSession()
        await loadMyRestaurants()
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        try? GIDSignIn.sharedInstance.signOut()
        currentUserID = nil
        currentUserEmail = nil
        myRestaurants = []
    }

    /// Permanently deletes the signed-in user's account (Apple Guideline 5.1.1(v):
    /// any app with account creation must offer in-app account deletion). Calls
    /// the `delete_user` Postgres function (security definer, scoped to
    /// `auth.uid()` — see migration 0005), which cascades to every restaurant,
    /// category, and item this account owns.
    func deleteAccount() async throws {
        let paths = myRestaurants.flatMap { r -> [String] in
            r.allItems.map { "\($0.id.uuidString).jpg" } + ["restaurant-\(r.id.uuidString).jpg"]
        }
        if !paths.isEmpty {
            try? await supabase.storage.from("menu-images").remove(paths: paths)
        }
        try await supabase.rpc("delete_user").execute()
        try? GIDSignIn.sharedInstance.signOut()
        currentUserID = nil
        currentUserEmail = nil
        myRestaurants = []
        selectedRestaurantID = nil
    }

    /// Signs in with Google via the native GoogleSignIn SDK, then exchanges the resulting
    /// ID token with Supabase Auth. `presentingViewController` is required by the SDK to
    /// host the Google account picker.
    func signInWithGoogle(presenting presentingViewController: UIViewController) async throws {
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(
                domain: "AppStore.GoogleSignIn", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "لم يصل رمز الدخول من قوقل"]
            )
        }
        try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
        )
        await checkSession()
        await loadMyRestaurants()
    }

    // MARK: - Sign in with Apple

    /// The raw nonce for the in-flight Apple sign-in request. `SignInWithAppleButton`
    /// needs the SHA256 hash at request time (`makeAppleNonce()`) and the raw value
    /// again at completion time to hand to Supabase — this is where it waits in between.
    private var currentAppleNonce: String?

    /// Generates a fresh random nonce, remembers it, and returns its SHA256 hash for
    /// `ASAuthorizationAppleIDRequest.nonce`. Required so Supabase can verify the ID
    /// token was issued for *this* request, not replayed from another one.
    func makeAppleNonce() -> String {
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        return Self.sha256(nonce)
    }

    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw NSError(
                domain: "AppStore.AppleSignIn", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "لم يصل رمز الدخول من أبل"]
            )
        }
        guard let nonce = currentAppleNonce else {
            throw NSError(
                domain: "AppStore.AppleSignIn", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "خطأ داخلي بجلسة الدخول، حاولي مرة ثانية"]
            )
        }
        try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
        currentAppleNonce = nil
        await checkSession()
        await loadMyRestaurants()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Favorites (local)

    func isFavorite(_ item: MenuItem) -> Bool { favoriteIDs.contains(item.id) }

    func toggleFavorite(_ item: MenuItem) {
        if favoriteIDs.contains(item.id) { favoriteIDs.remove(item.id) }
        else { favoriteIDs.insert(item.id) }
    }

    var favoriteItems: [(restaurant: Restaurant, item: MenuItem)] {
        restaurants.flatMap { r in
            r.allItems.filter { favoriteIDs.contains($0.id) }.map { (r, $0) }
        }
    }

    // MARK: - Owner: Add Category

    func addCategory(to restaurantID: UUID, nameEn: String, nameAr: String) async {
        do {
            // Claims the next index and increments it in one statement — see
            // migration 0010. Reading the counter and writing it back as two
            // round-trips let two concurrent adds read the same value and mint
            // the same letter.
            let claim: ClaimedCategoryIndex = try await supabase
                .rpc("claim_category_index", params: RestaurantIDParam(pRestaurantID: restaurantID))
                .single()
                .execute()
                .value

            let letter = Self.letterFromIndex(claim.claimedIndex)
            let displayOrder = myRestaurants.first(where: { $0.id == restaurantID })?.categories.count ?? 0

            struct InsertCategory: Encodable {
                let restaurantID: UUID
                let letter, name, nameAr: String
                let displayOrder: Int
                enum CodingKeys: String, CodingKey {
                    case restaurantID = "restaurant_id"
                    case letter, name
                    case nameAr = "name_ar"
                    case displayOrder = "display_order"
                }
            }
            try await supabase
                .from("menu_categories")
                .insert(InsertCategory(restaurantID: restaurantID, letter: letter,
                                       name: nameEn, nameAr: nameAr, displayOrder: displayOrder))
                .execute()

            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Owner: Add Item

    func addItem(to categoryID: UUID, restaurantID: UUID, nameEn: String, nameAr: String, price: Double) async {
        do {
            // Same atomic claim as addCategory — the letter and the number come
            // back from one statement, so no two products can share a code.
            let claim: ClaimedItemNumber = try await supabase
                .rpc("claim_item_number", params: CategoryIDParam(pCategoryID: categoryID))
                .single()
                .execute()
                .value

            let code = claim.claimedLetter + String(format: "%02d", claim.claimedNumber)
            let displayOrder = myRestaurants
                .first(where: { $0.id == restaurantID })?
                .categories.first(where: { $0.id == categoryID })?
                .items.count ?? 0

            struct InsertItem: Encodable {
                let categoryID: UUID
                let code, name, nameAr: String
                let price: Double
                let displayOrder: Int
                enum CodingKeys: String, CodingKey {
                    case categoryID = "category_id"
                    case code, name
                    case nameAr = "name_ar"
                    case price
                    case displayOrder = "display_order"
                }
            }
            try await supabase
                .from("menu_items")
                .insert(InsertItem(categoryID: categoryID, code: code, name: nameEn,
                                   nameAr: nameAr, price: price, displayOrder: displayOrder))
                .execute()

            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Owner: Toggle Availability

    func toggleAvailability(itemID: UUID, categoryID: UUID, restaurantID: UUID) async {
        guard let current = myRestaurants
            .first(where: { $0.id == restaurantID })?
            .categories.first(where: { $0.id == categoryID })?
            .items.first(where: { $0.id == itemID }) else { return }

        do {
            struct UpdateAvailability: Encodable {
                let isAvailable: Bool
                enum CodingKeys: String, CodingKey { case isAvailable = "is_available" }
            }
            try await supabase
                .from("menu_items")
                .update(UpdateAvailability(isAvailable: !current.isAvailable))
                .eq("id", value: itemID.uuidString)
                .execute()
            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Owner: Update Price

    func updatePrice(itemID: UUID, categoryID: UUID, restaurantID: UUID, price: Double) async {
        do {
            struct UpdatePrice: Encodable {
                let price: Double
            }
            try await supabase
                .from("menu_items")
                .update(UpdatePrice(price: price))
                .eq("id", value: itemID.uuidString)
                .execute()
            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Search

    func search(query: String) -> [(restaurant: Restaurant, item: MenuItem)] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let qLower = q.lowercased()
        return restaurants.flatMap { r in
            r.allItems.filter { item in
                item.code.lowercased() == qLower ||
                item.name.lowercased().contains(qLower) ||
                item.nameAr.contains(q)
            }.map { (r, $0) }
        }
    }

    // MARK: - Helpers

    /// Walks the key window's presented-controller chain to find a controller to host
    /// Google's account picker (GoogleSignIn needs a concrete UIViewController, which
    /// SwiftUI doesn't expose directly).
    static func topViewController() -> UIViewController? {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    /// A, B, … Z, AA, AB, … — spreadsheet-column (bijective base-26) numbering.
    ///
    /// This used to return a literal "?" past the 26th category, which is not a
    /// cosmetic limit: every category after the 26th then shared the letter "?",
    /// and since item numbers restart per category, two different products in the
    /// same restaurant both ended up as "?01". A code is the one thing a customer
    /// types to find a product, so a collision hands them the wrong item.
    ///
    /// Existing codes keep their meaning — the first 26 indices are unchanged.
    nonisolated static func letterFromIndex(_ index: Int) -> String {
        guard index >= 0 else { return "A" }
        var remaining = index
        var letters = ""
        repeat {
            letters = String(UnicodeScalar(65 + remaining % 26)!) + letters
            remaining = remaining / 26 - 1
        } while remaining >= 0
        return letters
    }
}
