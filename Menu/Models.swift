import Foundation

enum Language {
    case arabic, english
}

enum RestaurantType: String, CaseIterable {
    case restaurant = "restaurant"
    case cafe = "cafe"
    case kiosk = "kiosk"
    case foodTruck = "food_truck"

    func label(_ language: Language) -> String {
        switch self {
        case .restaurant: return language == .arabic ? "مطعم" : "Restaurant"
        case .cafe:       return language == .arabic ? "مقهى" : "Café"
        case .kiosk:      return language == .arabic ? "كشك" : "Kiosk"
        case .foodTruck:  return language == .arabic ? "عربة طعام" : "Food Truck"
        }
    }

    var icon: String {
        switch self {
        case .restaurant: return "fork.knife"
        case .cafe:       return "cup.and.saucer.fill"
        case .kiosk:      return "storefront"
        case .foodTruck:  return "truck.box.fill"
        }
    }
}

struct MenuItem: Identifiable {
    let id: UUID
    let code: String
    var name: String
    var nameAr: String
    var price: Double
    var isAvailable: Bool

    func displayName(_ language: Language) -> String {
        language == .arabic ? nameAr : name
    }
}

struct MenuCategory: Identifiable {
    let id: UUID
    let letter: String
    var name: String
    var nameAr: String
    var items: [MenuItem]

    func displayName(_ language: Language) -> String {
        language == .arabic ? nameAr : name
    }
}

struct Restaurant: Identifiable {
    let id: UUID
    var ownerID: UUID
    var name: String
    var nameAr: String
    var type: RestaurantType
    var descriptionEn: String
    var descriptionAr: String
    var isPublished: Bool
    var categories: [MenuCategory]

    func displayName(_ language: Language) -> String {
        language == .arabic ? nameAr : name
    }

    func displayDescription(_ language: Language) -> String {
        language == .arabic ? descriptionAr : descriptionEn
    }

    var allItems: [MenuItem] {
        categories.flatMap { $0.items }
    }
}
