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

    /// Answered by the database (`public.is_admin()` over the `app_admins`
    /// table, migration 0008) rather than by a list of emails compiled into the
    /// app. The old copy here and the copy inside the RLS policies were two
    /// lists that had to be edited together, and nothing enforced that.
    ///
    /// This is a convenience for routing the UI only. The real gate is in the
    /// database: approving or rejecting goes through `set_restaurant_status`,
    /// which re-checks admin membership itself and rejects anyone else.
    private(set) var isAdmin = false

    private static let favoritesDefaultsKey = "menu.favoriteItemIDs.v1"

    /// `loadOnStart: false` builds a store that touches no network — the unit
    /// tests construct `AppStore()` purely to exercise pure functions, and
    /// firing a session check and a restaurant load from `init` made every one
    /// of them do real I/O on the side.
    init(loadOnStart: Bool = true) {
        favoriteIDs = Self.loadPersistedFavorites()
        guard loadOnStart else { return }
        Task {
            await checkSession()
            await loadRestaurants()
        }
    }

    /// Raw PostgREST/network errors read like stack traces and leak backend
    /// shape to whoever is holding the phone. Everything the user sees goes
    /// through here; the underlying error still reaches the console.
    private func report(_ error: Error, fallback: String) {
        let raw = error.localizedDescription
        print("[menyu] \(fallback) — \(raw)")
        let text = raw.lowercased()
        if text.contains("offline") || text.contains("internet") || text.contains("network") || text.contains("timed out") {
            errorMessage = language == .arabic ? "لا يوجد اتصال بالإنترنت." : "No internet connection."
        } else if text.contains("row-level security") || text.contains("permission denied") || text.contains("42501") {
            errorMessage = language == .arabic ? "ليست لديك صلاحية لهذه العملية." : "You don't have permission for this."
        } else if text.contains("duplicate key") || text.contains("23505") {
            errorMessage = language == .arabic ? "هذا العنصر موجود مسبقًا." : "This item already exists."
        } else {
            errorMessage = fallback
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
                .eq("status", value: "approved")
                .order("created_at")
                .execute()
                .value
            restaurants = rows.map { $0.toRestaurant() }
            if isAuthenticated { await loadMyRestaurants() }
        } catch {
            report(error, fallback: language == .arabic ? "تعذّر تحميل المطاعم." : "Couldn't load restaurants.")
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
            report(error, fallback: language == .arabic ? "تعذّر تحميل مطاعمك." : "Couldn't load your restaurants.")
        }
    }

    // MARK: - Owner: Create Restaurant

    @discardableResult
    func createRestaurant(nameEn: String, nameAr: String, type: RestaurantType, descriptionEn: String, descriptionAr: String) async -> UUID? {
        guard let uid = currentUserID else { return nil }
        do {
            // No publish flag is sent: `status` defaults to 'pending' in the
            // database and `is_published` is generated from it, so a new
            // restaurant cannot be created already-live even by a modified client.
            struct InsertRestaurant: Encodable {
                let ownerID: UUID
                let name, nameAr, type, descriptionEn, descriptionAr: String
                enum CodingKeys: String, CodingKey {
                    case ownerID = "owner_id"
                    case name
                    case nameAr = "name_ar"
                    case type
                    case descriptionEn = "description_en"
                    case descriptionAr = "description_ar"
                }
            }

            let inserted: InsertedRow = try await supabase
                .from("restaurants")
                .insert(InsertRestaurant(
                    ownerID: uid,
                    name: nameEn, nameAr: nameAr, type: type.rawValue,
                    descriptionEn: descriptionEn, descriptionAr: descriptionAr
                ))
                .select("id")
                .single()
                .execute()
                .value

            await loadMyRestaurants()
            return inserted.id
        } catch {
            report(error, fallback: language == .arabic ? "تعذّر إنشاء المطعم." : "Couldn't create the restaurant.")
            return nil
        }
    }

    // MARK: - Owner: Update Store Details / Hours / Location / Delete

    /// Saves the fields the "مطعمي" form collects. Until migration 0008 there
    /// were no `phone`/`address` columns to save them into, and the screen's
    /// Save button showed a success toast while discarding everything typed.
    @discardableResult
    func updateRestaurantDetails(_ restaurantID: UUID, name: String, phone: String, address: String) async -> Bool {
        /// Writes only the keys it was given: the name column matching the
        /// language the form was filled in (the other keeps its own value), and
        /// phone/address, where an empty field legitimately means "clear it".
        struct UpdateDetails: Encodable {
            var name: String?
            var nameAr: String?
            var phone: String?
            var address: String?
            enum CodingKeys: String, CodingKey {
                case name
                case nameAr = "name_ar"
                case phone, address
            }
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                if let name { try c.encode(name, forKey: .name) }
                if let nameAr { try c.encode(nameAr, forKey: .nameAr) }
                try c.encode(phone, forKey: .phone)
                try c.encode(address, forKey: .address)
            }
        }

        func cleaned(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            var payload = UpdateDetails(phone: cleaned(phone), address: cleaned(address))
            if !trimmedName.isEmpty {
                if language == .arabic { payload.nameAr = trimmedName } else { payload.name = trimmedName }
            }
            try await supabase
                .from("restaurants")
                .update(payload)
                .eq("id", value: restaurantID.uuidString)
                .execute()
            await loadMyRestaurants()
            await loadRestaurants()
            return true
        } catch {
            report(error, fallback: language == .arabic ? "تعذّر حفظ بيانات المتجر." : "Couldn't save the store details.")
            return false
        }
    }

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
            report(error, fallback: language == .arabic ? "تعذّر حفظ أوقات الدوام." : "Couldn't save the hours.")
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
            report(error, fallback: language == .arabic ? "تعذّر حفظ الموقع." : "Couldn't save the location.")
        }
    }

    func deleteRestaurant(_ restaurantID: UUID) async {
        do {
            if let restaurant = myRestaurants.first(where: { $0.id == restaurantID }) {
                let paths = (restaurant.allItems.map(\.imageURL) + [restaurant.imageURL])
                    .compactMap(Self.storagePath(from:))
                if !paths.isEmpty {
                    try? await supabase.storage.from("menu-images").remove(paths: paths)
                }
            }
            try await supabase.from("restaurants").delete().eq("id", value: restaurantID.uuidString).execute()
            await loadMyRestaurants()
            await loadRestaurants()
            // Always leave selectedRestaurantID pointing at something real — otherwise
            // OwnerDashboardView is stuck showing its loading spinner forever with
            // nothing left to re-select it.
            if !myRestaurants.contains(where: { $0.id == selectedRestaurantID }) {
                selectedRestaurantID = myRestaurants.first?.id
            }
        } catch {
            report(error, fallback: language == .arabic ? "تعذّر حذف المطعم." : "Couldn't delete the restaurant.")
        }
    }

    // MARK: - Owner: Images

    private struct UpdateImage: Encodable {
        let imageURL: String
        enum CodingKeys: String, CodingKey { case imageURL = "image_url" }
    }

    /// The object path inside the `menu-images` bucket, read back out of a
    /// stored public URL. Deletes have to target the object that actually
    /// exists rather than re-deriving a naming convention, because the
    /// convention changed in 0008 and old rows still point at the old one.
    private static func storagePath(from urlString: String?) -> String? {
        guard let urlString, let range = urlString.range(of: "/menu-images/") else { return nil }
        var path = String(urlString[range.upperBound...])
        if let q = path.firstIndex(of: "?") { path = String(path[..<q]) }
        guard !path.isEmpty else { return nil }
        return path.removingPercentEncoding ?? path
    }

    /// Every upload writes a NEW object name under the owning restaurant's
    /// folder, then removes the one it replaced.
    ///
    /// The folder is what migration 0008's storage policies check, so a vendor
    /// can only write inside their own restaurant. The random suffix is what
    /// makes a replaced photo appear immediately: the old scheme reused one
    /// fixed name with `cacheControl: 3600`, so the public URL never changed
    /// and the previous image kept being served for up to an hour.
    private func uploadImage(_ data: Data, restaurantID: UUID, prefix: String, replacing previous: String?) async throws -> String {
        let path = "\(restaurantID.uuidString)/\(prefix)-\(UUID().uuidString).jpg"
        try await supabase.storage.from("menu-images").upload(
            path, data: data,
            options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false)
        )
        if let old = Self.storagePath(from: previous), old != path {
            try? await supabase.storage.from("menu-images").remove(paths: [old])
        }
        return try supabase.storage.from("menu-images").getPublicURL(path: path).absoluteString
    }

    @discardableResult
    func uploadItemImage(_ itemID: UUID, restaurantID: UUID, imageData: Data) async -> String? {
        do {
            let previous = myRestaurants.first(where: { $0.id == restaurantID })?
                .allItems.first(where: { $0.id == itemID })?.imageURL
            let url = try await uploadImage(imageData, restaurantID: restaurantID, prefix: itemID.uuidString, replacing: previous)
            try await supabase
                .from("menu_items")
                .update(UpdateImage(imageURL: url))
                .eq("id", value: itemID.uuidString)
                .execute()
            await loadMyRestaurants()
            return url
        } catch {
            report(error, fallback: language == .arabic ? "تعذّر رفع صورة المنتج." : "Couldn't upload the item photo.")
            return nil
        }
    }

    @discardableResult
    func uploadRestaurantImage(_ restaurantID: UUID, imageData: Data) async -> String? {
        do {
            let previous = myRestaurants.first(where: { $0.id == restaurantID })?.imageURL
            let url = try await uploadImage(imageData, restaurantID: restaurantID, prefix: "logo", replacing: previous)
            try await supabase
                .from("restaurants")
                .update(UpdateImage(imageURL: url))
                .eq("id", value: restaurantID.uuidString)
                .execute()
            await loadMyRestaurants()
            await loadRestaurants()
            return url
        } catch {
            report(error, fallback: language == .arabic ? "تعذّر رفع شعار المتجر." : "Couldn't upload the store logo.")
            return nil
        }
    }

    // MARK: - Owner: Delete Category / Item

    func deleteCategory(_ categoryID: UUID) async {
        do {
            let itemPaths = (myRestaurants
                .flatMap(\.categories)
                .first(where: { $0.id == categoryID })?
                .items ?? [])
                .compactMap { Self.storagePath(from: $0.imageURL) }
            if !itemPaths.isEmpty {
                try? await supabase.storage.from("menu-images").remove(paths: itemPaths)
            }
            try await supabase.from("menu_categories").delete().eq("id", value: categoryID.uuidString).execute()
            await loadMyRestaurants()
        } catch {
            report(error, fallback: language == .arabic ? "تعذّر حذف التصنيف." : "Couldn't delete the category.")
        }
    }

    func deleteItem(_ itemID: UUID) async {
        do {
            let path = myRestaurants.flatMap(\.allItems).first(where: { $0.id == itemID })?.imageURL
            if let path = Self.storagePath(from: path) {
                try? await supabase.storage.from("menu-images").remove(paths: [path])
            }
            try await supabase.from("menu_items").delete().eq("id", value: itemID.uuidString).execute()
            await loadMyRestaurants()
        } catch {
            report(error, fallback: language == .arabic ? "تعذّر حذف المنتج." : "Couldn't delete the item.")
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
            report(error, fallback: language == .arabic ? "تعذّر تحميل الطلبات." : "Couldn't load the review queue.")
        }
    }

    private struct SetStatusParams: Encodable {
        let restaurantID: UUID
        let status: String
        enum CodingKeys: String, CodingKey {
            case restaurantID = "p_restaurant_id"
            case status = "p_status"
        }
    }

    /// One call for all three transitions. It writes `status` only — the
    /// `is_published` column is generated from it — so the two can no longer
    /// disagree, and it re-checks admin membership inside the database, so the
    /// `guard isAdmin` below is a UI convenience rather than the actual gate.
    private func setStatus(_ restaurantID: UUID, _ status: String, failure: String) async {
        do {
            try await supabase
                .rpc("set_restaurant_status", params: SetStatusParams(restaurantID: restaurantID, status: status))
                .execute()
            await loadPendingRestaurants()
            await loadRestaurants()
        } catch {
            report(error, fallback: failure)
        }
    }

    func approveRestaurant(_ restaurantID: UUID) async {
        guard isAdmin else { return }
        await setStatus(restaurantID, "approved",
                        failure: language == .arabic ? "تعذّر اعتماد المطعم." : "Couldn't approve the restaurant.")
    }

    /// Permanently declines a pending application — it drops out of the
    /// review queue for good and never reaches customers. There's no
    /// owner-facing "rejected" screen yet; the restaurant just stays
    /// unpublished from the owner's point of view.
    func rejectRestaurant(_ restaurantID: UUID) async {
        guard isAdmin else { return }
        await setStatus(restaurantID, "rejected",
                        failure: language == .arabic ? "تعذّر رفض الطلب." : "Couldn't reject the request.")
    }

    /// Pulls an already-live restaurant back to pending — it disappears from
    /// customer surfaces immediately and returns to the review queue.
    func suspendRestaurant(_ restaurantID: UUID) async {
        guard isAdmin else { return }
        await setStatus(restaurantID, "pending",
                        failure: language == .arabic ? "تعذّر إيقاف النشر." : "Couldn't suspend the restaurant.")
    }

    // MARK: - Auth

    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            currentUserID = session.user.id
            currentUserEmail = session.user.email
            await refreshAdminFlag()
        } catch {
            currentUserID = nil
            currentUserEmail = nil
            isAdmin = false
        }
    }

    private func refreshAdminFlag() async {
        guard isAuthenticated else { isAdmin = false; return }
        do {
            // Read as raw bytes rather than decoding: the function returns a
            // bare JSON scalar (`true`), and a top-level fragment is exactly the
            // shape a JSON decoder is least dependable about.
            let response = try await supabase.rpc("is_admin").execute()
            let raw = String(data: response.data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            isAdmin = (raw == "true")
        } catch {
            // Never fail open: an unreachable check means "not an admin".
            print("[menyu] is_admin check failed — \(error.localizedDescription)")
            isAdmin = false
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
        isAdmin = false
        myRestaurants = []
        // Left behind before: the previous admin's review queue and the last
        // selected restaurant stayed in memory and rendered for whoever signed
        // in next on the same device.
        pendingRestaurants = []
        selectedRestaurantID = nil
        errorMessage = nil
    }

    /// Permanently deletes the signed-in user's account (Apple Guideline 5.1.1(v):
    /// any app with account creation must offer in-app account deletion). Calls
    /// the `delete_user` Postgres function (security definer, scoped to
    /// `auth.uid()` — see migration 0005), which cascades to every restaurant,
    /// category, and item this account owns.
    func deleteAccount() async throws {
        let paths = myRestaurants.flatMap { r -> [String?] in
            r.allItems.map(\.imageURL) + [r.imageURL]
        }.compactMap(Self.storagePath(from:))
        if !paths.isEmpty {
            try? await supabase.storage.from("menu-images").remove(paths: paths)
        }
        try await supabase.rpc("delete_user").execute()
        try? GIDSignIn.sharedInstance.signOut()
        currentUserID = nil
        currentUserEmail = nil
        isAdmin = false
        myRestaurants = []
        pendingRestaurants = []
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

    /// Delegates to `public.add_category`, which reserves the letter and
    /// inserts the row in one statement. The old path read
    /// `next_category_index`, inserted, then wrote the counter back from the
    /// app — three round trips during which a second add could reserve the
    /// same letter. It also computed `display_order` from the current count,
    /// which repeats a value as soon as anything has been deleted.
    @discardableResult
    func addCategory(to restaurantID: UUID, nameEn: String, nameAr: String) async -> Bool {
        struct Params: Encodable {
            let restaurantID: UUID
            let name, nameAr: String
            enum CodingKeys: String, CodingKey {
                case restaurantID = "p_restaurant_id"
                case name = "p_name"
                case nameAr = "p_name_ar"
            }
        }
        do {
            try await supabase
                .rpc("add_category", params: Params(restaurantID: restaurantID, name: nameEn, nameAr: nameAr))
                .execute()
            await loadMyRestaurants()
            return true
        } catch {
            report(error, fallback: language == .arabic ? "تعذّرت إضافة التصنيف." : "Couldn't add the category.")
            return false
        }
    }

    // MARK: - Owner: Add Item

    /// Delegates to `public.add_item` for the same reason as `addCategory`,
    /// and returns the new row's id.
    ///
    /// That id is what fixes photo attachment: the caller used to re-read the
    /// category and take `items.last`, but the list is sorted by
    /// `display_order`, so after any deletion the last element could be a
    /// different, older item — and the freshly picked photo was written onto it.
    func addItem(to categoryID: UUID, restaurantID: UUID, nameEn: String, nameAr: String, price: Double) async -> UUID? {
        struct Params: Encodable {
            let categoryID: UUID
            let name, nameAr: String
            let price: Double
            enum CodingKeys: String, CodingKey {
                case categoryID = "p_category_id"
                case name = "p_name"
                case nameAr = "p_name_ar"
                case price = "p_price"
            }
        }
        do {
            let response = try await supabase
                .rpc("add_item", params: Params(categoryID: categoryID, name: nameEn, nameAr: nameAr, price: price))
                .execute()
            // A function returning a composite comes back as an object, but
            // accept a one-element array too rather than lose the new row's id
            // — losing it is what sends the photo to the wrong item.
            let decoder = JSONDecoder()
            let created = (try? decoder.decode(InsertedRow.self, from: response.data))
                ?? (try? decoder.decode([InsertedRow].self, from: response.data))?.first
            await loadMyRestaurants()
            return created?.id
        } catch {
            report(error, fallback: language == .arabic ? "تعذّرت إضافة المنتج." : "Couldn't add the item.")
            return nil
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
            report(error, fallback: language == .arabic ? "تعذّر تغيير حالة التوفّر." : "Couldn't change availability.")
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
            report(error, fallback: language == .arabic ? "تعذّر حفظ السعر." : "Couldn't save the price.")
        }
    }

    // MARK: - Search

    /// Code matching stays exact (a code is an identifier, not free text).
    /// Name matching folds hamza/ta-marbuta/alef-maqsura and diacritics, so
    /// searching "اسبريسو" finds "إسبريسو" — previously it did not, because the
    /// Arabic branch was a plain literal `contains`.
    func search(query: String) -> [(restaurant: Restaurant, item: MenuItem)] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let folded = q.searchFolded
        guard !folded.isEmpty else { return [] }
        return restaurants.flatMap { r in
            r.allItems.filter { item in
                item.code.searchFolded == folded ||
                item.name.searchFolded.contains(folded) ||
                item.nameAr.searchFolded.contains(folded)
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

}
