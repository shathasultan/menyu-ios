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
    let isPublished: Bool
    /// Optional so rows written before migration 0006 (which added the column)
    /// still decode; those rows fall back to the published/unpublished reading.
    let status: String?
    let opensAt: String?
    let closesAt: String?
    let latitude: Double?
    let longitude: Double?
    let imageURL: String?
    let menuCategories: [MenuCategoryRow]?

    enum CodingKeys: String, CodingKey {
        case id, name, type, status, latitude, longitude
        case ownerID = "owner_id"
        case nameAr = "name_ar"
        case descriptionEn = "description_en"
        case descriptionAr = "description_ar"
        case nextCategoryIndex = "next_category_index"
        case isPublished = "is_published"
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
            isPublished: isPublished,
            status: status.flatMap(RestaurantStatus.init(rawValue:)) ?? (isPublished ? .approved : .pending),
            opensAt: opensAt,
            closesAt: closesAt,
            latitude: latitude,
            longitude: longitude,
            imageURL: imageURL,
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
        return MenuCategory(id: id, letter: letter, name: name, nameAr: nameAr, items: items)
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

// MARK: - Atomic code claims (migration 0010)
//
// These replace the read-then-write counter pair the app used to do over two
// round-trips. `claim_category_index` / `claim_item_number` increment and
// return in a single statement, so concurrent adds can't mint the same letter
// or the same product code.

struct RestaurantIDParam: Encodable {
    let pRestaurantID: UUID
    enum CodingKeys: String, CodingKey { case pRestaurantID = "p_restaurant_id" }
}

struct CategoryIDParam: Encodable {
    let pCategoryID: UUID
    enum CodingKeys: String, CodingKey { case pCategoryID = "p_category_id" }
}

struct ClaimedCategoryIndex: Decodable {
    let claimedIndex: Int
    enum CodingKeys: String, CodingKey { case claimedIndex = "claimed_index" }
}

struct ClaimedItemNumber: Decodable {
    let claimedLetter: String
    let claimedNumber: Int
    enum CodingKeys: String, CodingKey {
        case claimedLetter = "claimed_letter"
        case claimedNumber = "claimed_number"
    }
}
