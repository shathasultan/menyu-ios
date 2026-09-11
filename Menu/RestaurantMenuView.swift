import SwiftUI

struct RestaurantMenuView: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant

    var liveRestaurant: Restaurant {
        store.restaurants.first(where: { $0.id == restaurant.id }) ?? restaurant
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RestaurantHeader(restaurant: liveRestaurant)

                ForEach(liveRestaurant.categories) { category in
                    CategorySection(category: category)
                        .padding(.top, 8)
                }

                Spacer().frame(height: 20)
            }
        }
        .background(Color.mBackground)
        .navigationTitle(liveRestaurant.displayName(store.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(liveRestaurant.displayName(store.language)) · منيو") {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.mAccentStrong)
                }
            }
        }
    }
}

// MARK: - Restaurant Hero Header

private struct RestaurantHeader: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant

    var body: some View {
        VStack(spacing: 0) {
            // Warm accent hero
            ZStack {
                LinearGradient(
                    colors: [Color.mAccent, Color.mAccentStrong],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative circles for depth
                Circle().fill(.white.opacity(0.10)).frame(width: 180).offset(x: 90, y: -15)
                Circle().fill(.white.opacity(0.07)).frame(width: 110).offset(x: -70, y: 40)

                VStack(spacing: 12) {
                    Image(systemName: restaurant.type.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(.white)

                    // Type badge
                    HStack(spacing: 4) {
                        Image(systemName: restaurant.type.icon).font(.caption2)
                        Text(restaurant.type.label(store.language))
                            .font(.plexArabic(12, weight: .semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white.opacity(0.18))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }
            .frame(height: 165)

            // Restaurant info card
            VStack(spacing: 6) {
                Text(restaurant.displayName(store.language))
                    .font(.plexArabic(19, weight: .bold))
                    .foregroundStyle(Color.mInk)
                Text(restaurant.displayDescription(store.language))
                    .font(.plexArabic(13.5))
                    .foregroundStyle(Color.mInkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.mSurface)
        }
    }
}

// MARK: - Category Section

private struct CategorySection: View {
    @Environment(AppStore.self) private var store
    let category: MenuCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header bar
            HStack(spacing: 10) {
                Text(category.letter)
                    .font(.plexMono(14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.mAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .environment(\.layoutDirection, .leftToRight)

                Text(category.displayName(store.language))
                    .font(.plexArabic(15, weight: .bold))
                    .foregroundStyle(Color.mInk)

                Spacer()

                Text("\(category.items.count)")
                    .font(.plexMono(11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.mSurface2)
                    .foregroundStyle(Color.mInkSoft)
                    .clipShape(Capsule())
                    .environment(\.layoutDirection, .leftToRight)
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .background(Color.mBackground)

            // Item rows
            VStack(spacing: 0) {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    MenuItemRow(item: item)
                    if index < category.items.count - 1 {
                        Divider().padding(.leading, 78)
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
            CodeChip(code: item.code, large: false)
                .opacity(item.isAvailable ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName(store.language))
                    .font(.plexArabic(14, weight: .medium))
                    .strikethrough(!item.isAvailable, color: Color.mInkFaint)
                    .foregroundStyle(item.isAvailable ? Color.mInk : Color.mInkFaint)

                if item.isAvailable {
                    Text(priceText(item.price))
                        .font(.plexMono(13, weight: .semibold))
                        .foregroundStyle(Color.mInk)
                        .environment(\.layoutDirection, .leftToRight)
                } else {
                    Text(store.language == .arabic ? "غير متوفر" : "Unavailable")
                        .font(.plexArabic(11, weight: .bold))
                        .foregroundStyle(Color.mBad)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.mBadSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Spacer()

            Button {
                store.toggleFavorite(item)
            } label: {
                Image(systemName: store.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.system(size: 17))
                    .foregroundStyle(store.isFavorite(item) ? Color.mBad : Color.mInkSoft)
                    .frame(width: 30, height: 30)
                    .background(store.isFavorite(item) ? Color.mBadSoft : Color.mSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(store.isFavorite(item) ? Color.mBadSoft : Color.mLine, lineWidth: 1)
                    )
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
