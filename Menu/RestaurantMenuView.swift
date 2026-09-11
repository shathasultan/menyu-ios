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
        .background(Color(.systemGroupedBackground))
        .navigationTitle(liveRestaurant.displayName(store.language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(liveRestaurant.displayName(store.language)) · منيو") {
                    Image(systemName: "square.and.arrow.up")
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
            // Teal gradient hero
            ZStack {
                LinearGradient(
                    colors: [Color.brand, Color(red: 3/255, green: 105/255, blue: 97/255)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative circles for depth
                Circle().fill(.white.opacity(0.06)).frame(width: 180).offset(x: 90, y: -15)
                Circle().fill(.white.opacity(0.04)).frame(width: 110).offset(x: -70, y: 40)

                VStack(spacing: 12) {
                    Image(systemName: restaurant.type.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(.white)

                    // Type badge
                    HStack(spacing: 4) {
                        Image(systemName: restaurant.type.icon).font(.caption2)
                        Text(restaurant.type.label(store.language))
                            .font(.caption).fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white.opacity(0.18))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }
            .frame(height: 165)

            // Restaurant info card (white)
            VStack(spacing: 6) {
                Text(restaurant.displayName(store.language))
                    .font(.title2).fontWeight(.bold)
                Text(restaurant.displayDescription(store.language))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(.systemBackground))
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
                    .font(.system(.subheadline, design: .monospaced, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(category.displayName(store.language))
                    .font(.headline)

                Spacer()

                Text("\(category.items.count)")
                    .font(.caption2).fontWeight(.medium)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .background(Color(.systemGroupedBackground))

            // Item rows on white background
            VStack(spacing: 0) {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    MenuItemRow(item: item)
                    if index < category.items.count - 1 {
                        Divider().padding(.leading, 78)
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Menu Item Row

private struct MenuItemRow: View {
    @Environment(AppStore.self) private var store
    let item: MenuItem

    var body: some View {
        HStack(spacing: 14) {
            // Code badge — prominent, teal with glow shadow
            Text(item.code)
                .font(.system(.callout, design: .monospaced, weight: .black))
                .foregroundStyle(item.isAvailable ? .white : Color(.systemGray3))
                .frame(width: 50, height: 50)
                .background(item.isAvailable ? Color.brand : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .shadow(
                    color: item.isAvailable ? Color.brand.opacity(0.28) : .clear,
                    radius: 7, x: 0, y: 3
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName(store.language))
                    .font(.subheadline).fontWeight(.medium)
                    .strikethrough(!item.isAvailable, color: .secondary)
                    .foregroundStyle(item.isAvailable ? .primary : .secondary)

                if item.isAvailable {
                    Text(priceText(item.price))
                        .font(.footnote).fontWeight(.semibold)
                        .foregroundStyle(Color.brand)
                } else {
                    Text(store.language == .arabic ? "غير متوفر" : "Unavailable")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.toggleFavorite(item)
            } label: {
                Image(systemName: store.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.system(size: 19))
                    .foregroundStyle(store.isFavorite(item) ? .red : Color(.systemGray3))
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
