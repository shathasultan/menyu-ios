import SwiftUI

struct FavoritesView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.favoriteIDs.isEmpty {
                    ContentUnavailableView(
                        store.language == .arabic ? "لا توجد مفضلة" : "No Favorites",
                        systemImage: "heart",
                        description: Text(store.language == .arabic
                            ? "اضغط ♡ بجانب أي منتج لحفظه هنا"
                            : "Tap ♡ next to any item to save it here")
                    )
                } else {
                    List(store.favoriteItems, id: \.item.id) { entry in
                        FavoriteItemRow(restaurant: entry.restaurant, item: entry.item)
                            .listRowBackground(Color.mSurface)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.mBackground)
                }
            }
            .background(Color.mBackground)
            .navigationTitle(store.language == .arabic ? "مفضلاتي" : "Favorites")
        }
    }
}

private struct FavoriteItemRow: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant
    let item: MenuItem

    var body: some View {
        HStack(spacing: 12) {
            CodeChip(code: item.code)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName(store.language))
                    .font(.plexArabic(14, weight: .bold))
                    .foregroundStyle(Color.mInk)
                Text(restaurant.displayName(store.language))
                    .font(.plexArabic(12))
                    .foregroundStyle(Color.mInkSecondary)
            }

            Spacer()

            Text(priceText(item.price))
                .font(.plexMono(14, weight: .bold))
                .foregroundStyle(Color.mInk)
                .environment(\.layoutDirection, .leftToRight)

            Button {
                store.toggleFavorite(item)
            } label: {
                Image(systemName: "heart.fill").foregroundStyle(Color.mSage)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func priceText(_ price: Double) -> String {
        let n = Int(price)
        return store.language == .arabic ? "\(n) ر.س" : "SAR \(n)"
    }
}
