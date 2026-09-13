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
                    mascotEmptyState(
                        title: store.language == .arabic ? "ابحث عن منتج" : "Find an Item",
                        description: store.language == .arabic ? "ابحث بالاسم أو الرمز مثل A01" : "Search by name or code like A01"
                    )
                } else if results.isEmpty {
                    mascotEmptyState(
                        title: store.language == .arabic ? "لا توجد نتائج" : "No Results",
                        description: store.language == .arabic
                            ? "لا نتائج لـ \u{201C}\(query)\u{201D}. جرّبي حرف التصنيف مع الرقم، مثل A02."
                            : "No results for \u{201C}\(query)\u{201D}. Try the category letter with a number, like A02."
                    )
                } else {
                    List {
                        Text("\(results.count) \(store.language == .arabic ? "نتيجة لـ" : "results for") \u{201C}\(query)\u{201D}")
                            .font(.plexArabic(12, weight: .semibold))
                            .foregroundStyle(Color.mInkTertiary)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.mBackground)
                        ForEach(results, id: \.item.id) { result in
                            NavigationLink(destination: RestaurantMenuView(restaurant: result.restaurant)) {
                                SearchResultRow(restaurant: result.restaurant, item: result.item)
                            }
                            .listRowBackground(Color.mSurface)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.mBackground)
                }
            }
            .background(Color.mBackground)
            .searchable(
                text: $query,
                prompt: store.language == .arabic ? "اسم أو رمز مثل B02..." : "Name or code like B02..."
            )
            .navigationTitle(store.language == .arabic ? "بحث" : "Search")
        }
    }

    private func mascotEmptyState(title: String, description: String) -> some View {
        VStack(spacing: 14) {
            MenyuMascot(variant: .calm, bobDuration: 3.2)
                .frame(width: 86, height: 102)
            Text(title)
                .font(.plexArabicHeavy(17))
                .foregroundStyle(Color.mInk)
            Text(description)
                .font(.plexArabic(13))
                .foregroundStyle(Color.mInkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SearchResultRow: View {
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
                .font(.plexMono(15, weight: .bold))
                .foregroundStyle(Color.mInk)
                .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.vertical, 4)
    }

    private func priceText(_ price: Double) -> String {
        let n = Int(price)
        return store.language == .arabic ? "\(n) ر.س" : "SAR \(n)"
    }
}
