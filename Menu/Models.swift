import Foundation
import CoreLocation
import SwiftUI

extension Restaurant {
    /// No per-venue accent color is stored, so the logo placeholder tint
    /// rotates through the two role ramps for visual variety, keyed off a
    /// stable per-restaurant value (its id) rather than list position. The
    /// SAME formula everywhere a restaurant's logo placeholder renders — the
    /// venue detail hero and the home list card always agree on the color.
    var placeholderTint: (bg: Color, fg: Color) {
        let ramps: [(Color, Color)] = [(.mAccent100, .mAccent700), (.mSage100, .mSage700), (.mAccent200, .mAccent800), (.mSage200, .mSage800)]
        let index = abs(id.hashValue) % ramps.count
        return ramps[index]
    }
}

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
    var imageURL: String?

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
    var opensAt: String?
    var closesAt: String?
    var latitude: Double?
    var longitude: Double?
    var imageURL: String?
    var categories: [MenuCategory]

    var hasLocation: Bool { latitude != nil && longitude != nil }

    func displayName(_ language: Language) -> String {
        language == .arabic ? nameAr : name
    }

    func displayDescription(_ language: Language) -> String {
        language == .arabic ? descriptionAr : descriptionEn
    }

    var allItems: [MenuItem] {
        categories.flatMap { $0.items }
    }

    /// Real open/closed, computed from the vendor's own hours — never
    /// fabricated. `nil` when hours haven't been set yet.
    var isOpenNow: Bool? {
        guard let opensAt, let closesAt,
              let open = Self.minutesSinceMidnight(opensAt),
              let close = Self.minutesSinceMidnight(closesAt) else { return nil }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        guard let h = now.hour, let m = now.minute else { return nil }
        let nowMinutes = h * 60 + m
        if close > open {
            return nowMinutes >= open && nowMinutes < close
        } else {
            // Overnight range (e.g. 18:00–02:00).
            return nowMinutes >= open || nowMinutes < close
        }
    }

    private static func minutesSinceMidnight(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    /// Real distance from the given coordinate, using the vendor's own
    /// stored location. `nil` when either side is missing — never a guess.
    func distanceText(from userCoordinate: CLLocationCoordinate2D?, language: Language) -> String? {
        guard let userCoordinate, let latitude, let longitude else { return nil }
        let venue = CLLocation(latitude: latitude, longitude: longitude)
        let user = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let meters = venue.distance(from: user)
        if meters < 1000 {
            let m = Int(meters.rounded(to: 50))
            return language == .arabic ? "\(m) م" : "\(m) m"
        }
        let km = (meters / 1000).rounded(toPlaces: 1)
        return language == .arabic ? "\(km) كم" : "\(km) km"
    }
}

private extension Double {
    func rounded(to step: Double) -> Double { (self / step).rounded() * step }
    func rounded(toPlaces places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
