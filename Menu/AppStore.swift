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

    var isAuthenticated: Bool { currentUserID != nil }

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
                enum CodingKeys: String, CodingKey {
                    case ownerID = "owner_id"
                    case name
                    case nameAr = "name_ar"
                    case type
                    case descriptionEn = "description_en"
                    case descriptionAr = "description_ar"
                }
            }
            struct InsertedID: Decodable { let id: UUID }

            let inserted: InsertedID = try await supabase
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
