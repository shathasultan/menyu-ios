import Foundation
import CoreLocation
import SwiftUI

extension Restaurant {
    /// No per-venue accent color is stored, so the logo placeholder tint
    /// rotates through the two role ramps for visual variety, keyed off a
    /// stable per-restaurant value (its id) rather than list position. The
    /// SAME formula everywhere a restaurant's logo placeholder renders — the
    /// venue detail hero and the home list card always agree on the color.
    ///
    /// Derived from the UUID's own bytes, never from `hashValue`: Swift seeds
    /// `Hashable` randomly per process, so a hash-keyed tint would pick a new
    /// color on every launch and a different one on every device.
    var placeholderTint: (bg: Color, fg: Color) {
        let ramps: [(Color, Color)] = [(.mAccent100, .mAccent700), (.mSage100, .mSage700), (.mAccent200, .mAccent800), (.mSage200, .mSage800)]
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let sum = bytes.reduce(0) { ($0 + Int($1)) % ramps.count }
        return ramps[sum]
    }
}

enum Language {
    case arabic, english
}

/// The review state a restaurant is in — the single source of truth, matching
/// the `status` column. `isPublished` is derived from it in the database (a
/// generated column) and on the model below, so the two can never disagree.
enum RestaurantStatus: String {
    case pending, approved, rejected
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
    /// The number the database will give the next item in this category. Carried
    /// on the model so the "auto code" preview in the add sheet shows the code
    /// that will actually be assigned, instead of `items.count + 1` — which is a
    /// different number the moment anything has been deleted.
    var nextItemNumber: Int
    var items: [MenuItem]

    /// The exact code `public.add_item` will mint next.
    var nextItemCode: String { letter + String(format: "%02d", nextItemNumber) }

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
    var status: RestaurantStatus
    var opensAt: String?
    var closesAt: String?
    var latitude: Double?
    var longitude: Double?
    var imageURL: String?
    var phone: String?
    var address: String?
    /// The counter the database uses to mint the next category letter — same
    /// reason as `MenuCategory.nextItemNumber`.
    var nextCategoryIndex: Int
    var categories: [MenuCategory]

    /// The exact letter `public.add_category` will mint next, or nil past Z.
    var nextCategoryLetter: String? {
        guard nextCategoryIndex >= 0, nextCategoryIndex < 26 else { return nil }
        return String(UnicodeScalar(65 + nextCategoryIndex)!)
    }

    /// Derived, never stored separately — mirrors the database's generated
    /// `is_published` column so the app can't drift from it.
    var isPublished: Bool { status == .approved }

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
    ///
    /// Evaluated in the venue's own timezone, not the phone's: `opens_at` and
    /// `closes_at` are stored as bare "HH:mm" local to the restaurant, so a
    /// customer whose phone is in another timezone would otherwise be told a
    /// Riyadh café is closed while it's open.
    var isOpenNow: Bool? {
        guard let opensAt, let closesAt,
              let open = Self.minutesSinceMidnight(opensAt),
              let close = Self.minutesSinceMidnight(closesAt) else { return nil }
        let now = Self.venueCalendar.dateComponents([.hour, .minute], from: Date())
        guard let h = now.hour, let m = now.minute else { return nil }
        let nowMinutes = h * 60 + m
        if close > open {
            return nowMinutes >= open && nowMinutes < close
        } else {
            // Overnight range (e.g. 18:00–02:00).
            return nowMinutes >= open || nowMinutes < close
        }
    }

    /// Every venue in scope today is in Riyadh; when the app expands beyond one
    /// city this becomes a per-restaurant column instead of a constant.
    static let venueCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Riyadh") ?? .current
        return c
    }()

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

// MARK: - Money

/// One price formatter for the whole app. Prices are `numeric(10,2)` in the
/// database, so truncating with `Int(price)` silently dropped halalas — 14.50
/// rendered as "14". Whole riyals still read as whole riyals.
enum Money {
    static func text(_ price: Double, language: Language) -> String {
        let amount = formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
        return language == .arabic ? "\(amount) ر.س" : "SAR \(amount)"
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    /// Reads a price the vendor typed. Accepts Arabic-Indic digits (٠١٢٣) and
    /// an Arabic decimal separator, both of which a real Arabic keypad
    /// produces and `Double("١٤٫٥")` rejects outright.
    static func parse(_ input: String) -> Double? {
        let normalized = input
            .trimmingCharacters(in: .whitespaces)
            .applyingTransform(.toLatin, reverse: false)?
            .replacingOccurrences(of: "٫", with: ".")
            .replacingOccurrences(of: "،", with: ".")
            .replacingOccurrences(of: ",", with: ".")
            ?? input
        return Double(normalized)
    }
}

// MARK: - Opening hours

/// Converts between the picker's value and the bare "HH:mm" string the database
/// stores.
///
/// This used to go through a `DateFormatter` with no locale, which on a phone
/// set to Arabic wrote "٠٩:٠٠" into the database; reading it back,
/// `Int(parts[0])` is nil, so `isOpenNow` returned nil and the venue showed
/// neither open nor closed, permanently, for everyone. Working in plain minutes
/// removes the formatter — and the locale — from the path entirely.
enum Hours {
    /// Minutes since midnight — what the chip picker works in. There is no
    /// `Date` and no `DateFormatter` anywhere on this path any more, so the
    /// locale can't get a vote: `String(format:)` writes Latin digits always.
    static func minutes(_ hhmm: String?, defaultHour: Int) -> Int {
        guard let hhmm else { return defaultHour * 60 }
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0..<24).contains(h), (0..<60).contains(m) else { return defaultHour * 60 }
        return h * 60 + m
    }

    static func text(minutes: Int) -> String {
        let clamped = max(0, min(minutes, 24 * 60 - 1))
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

}

// MARK: - Arabic text matching

extension String {
    /// Folds the differences that make Arabic search miss the obvious match:
    /// hamza forms (أ إ آ → ا), ta marbuta (ة → ه), alef maqsura (ى → ي),
    /// tatweel, and diacritics. Also lowercases, so one comparison serves both
    /// languages.
    var searchFolded: String {
        var s = folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ar"))
        for (from, to) in [("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ٱ", "ا"), ("ة", "ه"), ("ى", "ي"), ("ـ", "")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}

private extension Double {
    func rounded(to step: Double) -> Double { (self / step).rounded() * step }
    func rounded(toPlaces places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (self * f).rounded() / f
    }
}
