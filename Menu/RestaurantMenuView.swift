import SwiftUI
import CoreLocation

struct RestaurantMenuView: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant

    /// `nil` = "الكل" (all categories shown); otherwise filters to one category.
    @State private var selectedCategoryID: MenuCategory.ID?
    @State private var location = LocationProvider()

    var liveRestaurant: Restaurant {
        store.restaurants.first(where: { $0.id == restaurant.id }) ?? restaurant
    }

    private var visibleCategories: [MenuCategory] {
        guard let id = selectedCategoryID else { return liveRestaurant.categories }
        return liveRestaurant.categories.filter { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 0) {
                RestaurantHeader(restaurant: liveRestaurant, userCoordinate: location.coordinate)

                if liveRestaurant.categories.count > 1 {
                    CategoryTabBar(
                        categories: liveRestaurant.categories,
                        selectedID: $selectedCategoryID,
                        language: store.language
                    )
                    .padding(.top, 14)
                }

                ForEach(visibleCategories) { category in
                    CategorySection(restaurant: liveRestaurant, category: category)
                        .padding(.top, 8)
                }

                Spacer().frame(height: 20)
            }
        }
        .background(Color.mBackground)
        .navigationBarHidden(true)
        .ignoresSafeArea(edges: .top)
        .onAppear { location.requestIfNeeded() }
    }
}

// MARK: - Category Tab Bar

/// Horizontal «الكل» + one pill per category (`<letter> · <name>`), filtering
/// which category's items are shown below.
private struct CategoryTabBar: View {
    let categories: [MenuCategory]
    @Binding var selectedID: MenuCategory.ID?
    let language: Language

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MFilterChip(label: language == .arabic ? "الكل" : "All", selected: selectedID == nil) {
                    selectedID = nil
                }
                ForEach(categories) { category in
                    MFilterChip(
                        label: "\(category.letter) · \(category.displayName(language))",
                        selected: selectedID == category.id
                    ) {
                        selectedID = category.id
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Restaurant Hero Header

private struct RestaurantHeader: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let restaurant: Restaurant
    var userCoordinate: CLLocationCoordinate2D?

    private var isArabic: Bool { store.language == .arabic }
    private var tint: (bg: Color, fg: Color) { restaurant.placeholderTint }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Hero: soft decorative ground, the same logo used on the home
            // card, the mascot, and the back/share row — no native nav bar.
            ZStack(alignment: .topLeading) {
                tint.bg.opacity(0.5)
                Circle().fill(tint.bg).frame(width: 260).offset(x: 90, y: -110)
                Circle().fill(Color.mSage100).frame(width: 160).offset(x: -140, y: 60)

                MenyuMascot(variant: .default, bobDuration: 3.4)
                    .frame(width: 62, height: 74)
                    .padding(.trailing, 20)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.mInk)
                                .frame(width: 38, height: 38)
                                .background(.white)
                                .clipShape(Circle())
                        }
                        Spacer()
                        ShareLink(item: "\(restaurant.displayName(store.language)) · menu.") {
                            HStack(spacing: 6) {
                                Text(isArabic ? "شارك المنيو" : "Share Menu")
                                    .font(.plexArabic(12.5, weight: .bold))
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(Color.mInk)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.white)
                            .clipShape(Capsule())
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 54)

                logoTile
                    .padding(.top, 100)
                    .padding(.leading, 20)
            }
            .frame(height: 230)

            // Name / status / distance
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 8) {
                    Text(restaurant.displayName(store.language))
                        .font(.plexArabicHeavy(22))
                        .foregroundStyle(Color.mInk)
                    if let isOpen = restaurant.isOpenNow {
                        MTag(
                            text: isOpen ? (isArabic ? "مفتوح الآن" : "Open Now") : (isArabic ? "مسكّر" : "Closed"),
                            style: isOpen ? .tinted(.mSage100, .mSage800) : .neutral
                        )
                    }
                }
                HStack(spacing: 4) {
                    Text(restaurant.type.label(store.language))
                    if let distance = restaurant.distanceText(from: userCoordinate, language: store.language) {
                        Text("·")
                        Text(distance)
                    }
                }
                .font(.plexArabic(12.5))
                .foregroundStyle(Color.mInkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.mSurface)
        }
    }

    /// The exact same logo/placeholder treatment as the home card, so the
    /// venue looks identical whether you're browsing the list or inside it.
    private var logoTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MTheme.radiusLogo, style: .continuous)
                .fill(tint.bg)
            if let urlString = restaurant.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color.clear }
                    .clipShape(RoundedRectangle(cornerRadius: MTheme.radiusLogo, style: .continuous))
            } else {
                Image(systemName: restaurant.type.icon)
                    .font(.system(size: 26))
                    .foregroundStyle(tint.fg)
            }
        }
        .frame(width: 78, height: 78)
        .overlay(RoundedRectangle(cornerRadius: MTheme.radiusLogo, style: .continuous).strokeBorder(.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Category Section

private struct CategorySection: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant
    let category: MenuCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header bar
            HStack(spacing: 10) {
                Text(category.displayName(store.language))
                    .font(.plexArabic(15, weight: .bold))
                    .foregroundStyle(Color.mInk)

                Text(category.letter)
                    .font(.plexMono(14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.mInk)
                    .clipShape(Circle())
                    .environment(\.layoutDirection, .leftToRight)

                Spacer()

                Text("\(category.items.count)")
                    .font(.plexMono(11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.mSurface2)
                    .foregroundStyle(Color.mInkSecondary)
                    .clipShape(Capsule())
                    .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .background(Color.mBackground)

            // Item rows
            VStack(spacing: 0) {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(destination: ItemDetailView(restaurant: restaurant, item: item)) {
                        MenuItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                    if index < category.items.count - 1 {
                        Divider().padding(.trailing, 76)
                    }
                }
            }
            .background(Color.mSurface)
        }
    }
}

// MARK: - Menu Item Row

private struct MenuItemRow: View {
    @Environment(AppStore.self) private var store
    let item: MenuItem

    var body: some View {
        HStack(spacing: 14) {
            CodeChip(code: item.code, large: true)
                .opacity(item.isAvailable ? 1 : 0.5)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.mSurface2)
                if let urlString = item.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color.clear }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.displayName(store.language))
                    .font(.plexArabic(14, weight: .semibold))
                    .strikethrough(!item.isAvailable, color: Color.mInkFaint)
                    .foregroundStyle(item.isAvailable ? Color.mInk : Color.mInkFaint)
                Text(store.language == .arabic ? item.name : item.nameAr)
                    .font(.plexMono(10.5))
                    .foregroundStyle(Color.mInkFaint)
                    .environment(\.layoutDirection, .leftToRight)
            }

            Spacer()

            if item.isAvailable {
                Text(priceText(item.price))
                    .font(.plexMono(15, weight: .bold))
                    .foregroundStyle(Color.mInk)
                    .environment(\.layoutDirection, .leftToRight)
            } else {
                Text(store.language == .arabic ? "غير متوفر" : "Unavailable")
                    .font(.plexArabic(11, weight: .bold))
                    .foregroundStyle(Color.mInkSecondary)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Color.mChipFill)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Button {
                store.toggleFavorite(item)
            } label: {
                Image(systemName: store.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.system(size: 15))
                    .foregroundStyle(store.isFavorite(item) ? Color.mSage800 : Color.mInkSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 13)
    }

    private func priceText(_ price: Double) -> String {
        let n = Int(price)
        return store.language == .arabic ? "\(n) ر.س" : "SAR \(n)"
    }
}
