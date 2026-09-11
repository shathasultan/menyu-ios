import SwiftUI

struct SearchView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""

    var results: [(restaurant: Restaurant, item: MenuItem)] {
        store.search(query: query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView(
                        store.language == .arabic ? "ابحث عن منتج" : "Find an Item",
                        systemImage: "magnifyingglass",
                        description: Text(store.language == .arabic
                            ? "ابحث بالاسم أو الرمز مثل A01"
                            : "Search by name or code like A01")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results, id: \.item.id) { result in
                        NavigationLink(destination: RestaurantMenuView(restaurant: result.restaurant)) {
                            SearchResultRow(restaurant: result.restaurant, item: result.item)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(
                text: $query,
                prompt: store.language == .arabic ? "اسم أو رمز مثل B02..." : "Name or code like B02..."
            )
            .navigationTitle(store.language == .arabic ? "بحث" : "Search")
        }
    }
}

private struct SearchResultRow: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant
    let item: MenuItem

    var body: some View {
        HStack(spacing: 10) {
            Text(item.code)
                .font(.system(.callout, design: .monospaced, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.brand)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName(store.language))
                    .font(.subheadline).fontWeight(.medium)
                Text(restaurant.displayName(store.language))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Text(priceText(item.price))
                .font(.footnote).fontWeight(.semibold)
                .foregroundStyle(Color.brand)
        }
    }

    private func priceText(_ price: Double) -> String {
        let n = Int(price)
        return store.language == .arabic ? "\(n) ر.س" : "SAR \(n)"
    }
}
