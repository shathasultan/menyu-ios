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
    let menuCategories: [MenuCategoryRow]?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case ownerID = "owner_id"
        case nameAr = "name_ar"
        case descriptionEn = "description_en"
        case descriptionAr = "description_ar"
        case nextCategoryIndex = "next_category_index"
        case isPublished = "is_published"
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

    enum CodingKeys: String, CodingKey {
        case id, code, name
        case nameAr = "name_ar"
        case price
        case isAvailable = "is_available"
        case displayOrder = "display_order"
    }

    func toMenuItem() -> MenuItem {
        MenuItem(id: id, code: code, name: name, nameAr: nameAr, price: price, isAvailable: isAvailable)
    }
}

// MARK: - Small read helpers

struct NextCategoryIndexRow: Codable {
    let nextCategoryIndex: Int
    enum CodingKeys: String, CodingKey { case nextCategoryIndex = "next_category_index" }
}

struct CategoryInfoRow: Codable {
    let letter: String
    let nextItemNumber: Int
    enum CodingKeys: String, CodingKey {
        case letter
        case nextItemNumber = "next_item_number"
    }
}
