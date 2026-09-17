import SwiftUI

/// C4 in the flow spec — full-screen detail for a single menu item.
struct ItemDetailView: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant
    let item: MenuItem

    private var liveItem: MenuItem {
        restaurant.allItems.first(where: { $0.id == item.id }) ?? item
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let urlString = liveItem.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.mSurface2
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous))
                    .padding(.top, 20)
                }

                CodeChip(code: liveItem.code, large: true)
                    .padding(.top, liveItem.imageURL == nil ? 28 : 8)

                VStack(spacing: 6) {
                    Text(liveItem.displayName(store.language))
                        .font(.plexArabic(20, weight: .bold))
                        .foregroundStyle(Color.mInk)
                        .multilineTextAlignment(.center)

                    Text(restaurant.displayName(store.language))
                        .font(.plexArabic(13.5))
                        .foregroundStyle(Color.mInkSecondary)
                }

                Text(Money.text(liveItem.price, language: store.language))
                    .font(.plexMono(19, weight: .bold))
                    .foregroundStyle(Color.mInk)
                    .environment(\.layoutDirection, .leftToRight)

                if !liveItem.isAvailable {
                    Text(store.language == .arabic ? "غير متوفر حاليًا" : "Currently unavailable")
                        .font(.plexArabic(12, weight: .bold))
                        .foregroundStyle(Color.mInkSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Color.mChipFill)
                        .clipShape(Capsule())
                }

                Button {
                    store.toggleFavorite(liveItem)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: store.isFavorite(liveItem) ? "heart.fill" : "heart")
                        Text(store.isFavorite(liveItem)
                             ? (store.language == .arabic ? "في المفضلة" : "In Favorites")
                             : (store.language == .arabic ? "أضف للمفضلة" : "Add to Favorites"))
                    }
                    .font(.plexArabic(14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(store.isFavorite(liveItem) ? Color.mSage200 : Color.mSurface2)
                    .foregroundStyle(store.isFavorite(liveItem) ? Color.mSage900 : Color.mInkSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: MTheme.radiusSmall))
                }
                .padding(.horizontal, 32)
                .padding(.top, 4)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.mBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: "\(liveItem.code) · \(liveItem.displayName(store.language)) · \(restaurant.displayName(store.language)) · منيو") {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.mAccent800)
                }
            }
        }
    }
}
