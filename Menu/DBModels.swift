import Foundation

// MARK: - DB Row Types
// These decode Supabase's snake_case JSON into app models.

struct RestaurantRow: Codable {
    let id: UUID
    let ownerID: UUID
    let name: String
    let nameAr: String
    let type: String
    let descriptionEn: String
    let descriptionAr: String
    let nextCategoryIndex: Int
    /// The review state. `is_published` also comes back on `select *`, but it's
    /// a generated column derived from this one — decoding it too would just
    /// give the app a second copy of the same fact to drift from.
    let status: String
    let opensAt: String?
    let closesAt: String?
    let latitude: Double?
    let longitude: Double?
    let imageURL: String?
    let phone: String?
    let address: String?
    let menuCategories: [MenuCategoryRow]?

    enum CodingKeys: String, CodingKey {
        case id, name, type, latitude, longitude, status, phone, address
        case ownerID = "owner_id"
        case nameAr = "name_ar"
        case descriptionEn = "description_en"
        case descriptionAr = "description_ar"
        case nextCategoryIndex = "next_category_index"
        case opensAt = "opens_at"
        case closesAt = "closes_at"
        case imageURL = "image_url"
        case menuCategories = "menu_categories"
    }

    func toRestaurant() -> Restaurant {
        let cats = (menuCategories ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
            .map { $0.toMenuCategory() }
        return Restaurant(
            id: id,
            ownerID: ownerID,
            name: name,
            nameAr: nameAr,
            type: RestaurantType(rawValue: type) ?? .restaurant,
            descriptionEn: descriptionEn,
            descriptionAr: descriptionAr,
            status: RestaurantStatus(rawValue: status) ?? .pending,
            opensAt: opensAt,
            closesAt: closesAt,
            latitude: latitude,
            longitude: longitude,
            imageURL: imageURL,
            phone: phone,
            address: address,
            nextCategoryIndex: nextCategoryIndex,
            categories: cats
        )
    }
}

struct MenuCategoryRow: Codable {
    let id: UUID
    let letter: String
    let name: String
    let nameAr: String
    let displayOrder: Int
    let nextItemNumber: Int
    let menuItems: [MenuItemRecord]?

    enum CodingKeys: String, CodingKey {
        case id, letter, name
        case nameAr = "name_ar"
        case displayOrder = "display_order"
        case nextItemNumber = "next_item_number"
        case menuItems = "menu_items"
    }

    func toMenuCategory() -> MenuCategory {
        let items = (menuItems ?? [])
            .sorted { $0.displayOrder < $1.displayOrder }
            .map { $0.toMenuItem() }
        return MenuCategory(id: id, letter: letter, name: name, nameAr: nameAr, nextItemNumber: nextItemNumber, items: items)
    }
}

struct MenuItemRecord: Codable {
    let id: UUID
    let code: String
    let name: String
    let nameAr: String
    let price: Double
    let isAvailable: Bool
    let displayOrder: Int
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id, code, name
        case nameAr = "name_ar"
        case price
        case isAvailable = "is_available"
        case displayOrder = "display_order"
        case imageURL = "image_url"
    }

    func toMenuItem() -> MenuItem {
        MenuItem(id: id, code: code, name: name, nameAr: nameAr, price: price, isAvailable: isAvailable, imageURL: imageURL)
    }
}

// MARK: - Small read helpers

/// Rows returned by the `add_category` / `add_item` database functions, which
/// allocate the letter/number atomically server-side. The app only needs the
/// new row's id — to attach a freshly picked photo to the item that was just
/// created, instead of guessing at the end of a re-sorted list.
struct InsertedRow: Decodable {
    let id: UUID
}
