import SwiftUI
import Supabase
import PostgREST
import GoogleSignIn

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

    /// Single hardcoded reviewer for now — there is exactly one person operating this app.
    /// Move to a real roles table if a second admin is ever needed.
    private static let adminEmail = "shathasultann9@gmail.com"
    var isAdmin: Bool { currentUserEmail == Self.adminEmail }

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
            try await supabase.from("restaurants").delete().eq("id", value: restaurantID.uuidString).execute()
            if selectedRestaurantID == restaurantID { selectedRestaurantID = nil }
            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Owner: Item Image

    @discardableResult
    func uploadItemImage(_ itemID: UUID, imageData: Data) async -> String? {
        do {
            let path = "\(itemID.uuidString).jpg"
            try await supabase.storage.from("menu-images").upload(
                path, data: imageData,
                options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
            )
            let publicURL = try supabase.storage.from("menu-images").getPublicURL(path: path)

            struct UpdateImage: Encodable {
                let imageURL: String
                enum CodingKeys: String, CodingKey { case imageURL = "image_url" }
            }
            try await supabase
                .from("menu_items")
                .update(UpdateImage(imageURL: publicURL.absoluteString))
                .eq("id", value: itemID.uuidString)
                .execute()
            await loadMyRestaurants()
            return publicURL.absoluteString
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

            struct UpdateImage: Encodable {
                let imageURL: String
                enum CodingKeys: String, CodingKey { case imageURL = "image_url" }
            }
            try await supabase
                .from("restaurants")
                .update(UpdateImage(imageURL: publicURL.absoluteString))
                .eq("id", value: restaurantID.uuidString)
                .execute()
            await loadMyRestaurants()
            await loadRestaurants()
            return publicURL.absoluteString
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Owner: Delete Category / Item

    func deleteCategory(_ categoryID: UUID) async {
        do {
            try await supabase.from("menu_categories").delete().eq("id", value: categoryID.uuidString).execute()
            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ itemID: UUID) async {
        do {
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
            let rows: [RestaurantRow] = try await supabase
                .from("restaurants")
                .select("*, menu_categories(*, menu_items(*))")
                .eq("is_published", value: false)
                .order("created_at")
                .execute()
                .value
            pendingRestaurants = rows.map { $0.toRestaurant() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approveRestaurant(_ restaurantID: UUID) async {
        guard isAdmin else { return }
        do {
            struct Publish: Encodable {
                let isPublished: Bool
                enum CodingKeys: String, CodingKey { case isPublished = "is_published" }
            }
            try await supabase
                .from("restaurants")
                .update(Publish(isPublished: true))
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

    func signUp(email: String, password: String) async throws {
        try await supabase.auth.signUp(email: email, password: password)
        await checkSession()
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        try? GIDSignIn.sharedInstance.signOut()
        currentUserID = nil
        currentUserEmail = nil
        myRestaurants = []
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
            let indexRow: NextCategoryIndexRow = try await supabase
                .from("restaurants")
                .select("next_category_index")
                .eq("id", value: restaurantID.uuidString)
                .single()
                .execute()
                .value

            let letter = letterFromIndex(indexRow.nextCategoryIndex)
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

            struct IncrementIndex: Encodable {
                let nextCategoryIndex: Int
                enum CodingKeys: String, CodingKey { case nextCategoryIndex = "next_category_index" }
            }
            try await supabase
                .from("restaurants")
                .update(IncrementIndex(nextCategoryIndex: indexRow.nextCategoryIndex + 1))
                .eq("id", value: restaurantID.uuidString)
                .execute()

            await loadMyRestaurants()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Owner: Add Item

    func addItem(to categoryID: UUID, restaurantID: UUID, nameEn: String, nameAr: String, price: Double) async {
        do {
            let catInfo: CategoryInfoRow = try await supabase
                .from("menu_categories")
                .select("letter, next_item_number")
                .eq("id", value: categoryID.uuidString)
                .single()
                .execute()
                .value

            let code = catInfo.letter + String(format: "%02d", catInfo.nextItemNumber)
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

            struct IncrementItemNumber: Encodable {
                let nextItemNumber: Int
                enum CodingKeys: String, CodingKey { case nextItemNumber = "next_item_number" }
            }
            try await supabase
                .from("menu_categories")
                .update(IncrementItemNumber(nextItemNumber: catInfo.nextItemNumber + 1))
                .eq("id", value: categoryID.uuidString)
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

    private func letterFromIndex(_ index: Int) -> String {
        guard index >= 0 && index < 26 else { return "?" }
        return String(UnicodeScalar(65 + index)!)
    }
}
