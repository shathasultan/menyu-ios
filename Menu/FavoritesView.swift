import SwiftUI

struct FavoritesView: View {
    @Environment(AppStore.self) private var store

    var grouped: [(id: UUID, restaurant: Restaurant, items: [MenuItem])] {
        var dict: [UUID: (restaurant: Restaurant, items: [MenuItem])] = [:]
        for entry in store.favoriteItems {
            if dict[entry.restaurant.id] == nil {
                dict[entry.restaurant.id] = (entry.restaurant, [])
            }
            dict[entry.restaurant.id]?.items.append(entry.item)
        }
        return dict
            .map { (id: $0.key, restaurant: $0.value.restaurant, items: $0.value.items) }
            .sorted { $0.restaurant.displayName(store.language) < $1.restaurant.displayName(store.language) }
    }

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
                    List {
                        ForEach(grouped, id: \.id) { group in
                            Section {
                                ForEach(group.items) { item in
                                    FavoriteItemRow(item: item)
                                }
                                .listRowBackground(Color.mSurface)
                            } header: {
                                Text(group.restaurant.displayName(store.language))
                                    .font(.plexArabic(12.5, weight: .semibold))
                                    .foregroundStyle(Color.mInkSoft)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.mBackground)
                }
            }
            .background(Color.mBackground)
            .navigationTitle(store.language == .arabic ? "المفضلة" : "Favorites")
        }
    }
}

private struct FavoriteItemRow: View {
    @Environment(AppStore.self) private var store
    let item: MenuItem

    var body: some View {
        HStack(spacing: 12) {
            CodeChip(code: item.code)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName(store.language))
                    .font(.plexArabic(14, weight: .medium))
                    .foregroundStyle(Color.mInk)
                Text(priceText(item.price))
                    .font(.plexMono(12, weight: .semibold))
                    .foregroundStyle(Color.mInk)
                    .environment(\.layoutDirection, .leftToRight)
            }

            Spacer()

            Button {
                store.toggleFavorite(item)
            } label: {
                Image(systemName: "heart.fill").foregroundStyle(Color.mBad)
            }
            .buttonStyle(.plain)
        }
    }

    private func priceText(_ price: Double) -> String {
        let n = Int(price)
        return store.language == .arabic ? "\(n) ر.س" : "SAR \(n)"
    }
}
