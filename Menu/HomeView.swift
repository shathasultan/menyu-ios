import SwiftUI
import CoreLocation

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedType: RestaurantType? = nil
    @State private var query = ""
    @State private var location = LocationProvider()

    private var isArabic: Bool { store.language == .arabic }

    var filtered: [Restaurant] {
        var list = store.restaurants
        if let type = selectedType { list = list.filter { $0.type == type } }
        let folded = query.searchFolded
        guard !folded.isEmpty else { return list }
        // Both names, folded — typing an Arabic name with a different hamza
        // form, or an English name while the app is in Arabic, used to find
        // nothing at all.
        return list.filter {
            $0.nameAr.searchFolded.contains(folded) || $0.name.searchFolded.contains(folded)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .trailing, spacing: 18) {
                    header

                    Text(isArabic ? "وش تشرب اليوم؟" : "What are you drinking today?")
                        .font(.plexArabicHeavy(26))
                        .foregroundStyle(Color.mInk)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    searchField
                    filterChips

                    HStack {
                        Text(isArabic ? "قريب منك" : "Near You")
                            .font(.plexArabic(15, weight: .bold))
                            .foregroundStyle(Color.mInk)
                        Spacer()
                        if !store.isLoading {
                            Text("\(filtered.count) \(isArabic ? "مكان" : "places")")
                                .font(.plexArabic(12))
                                .foregroundStyle(Color.mInkTertiary)
                        }
                    }

                    content
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(Color.mBackground)
            .refreshable {
                await store.loadRestaurants()
                location.requestIfNeeded()
            }
            .navigationBarHidden(true)
            .onAppear { location.requestIfNeeded() }
        }
    }

    private var header: some View {
        HStack {
            Text("menu.")
                .font(.plexMono(21, weight: .heavy))
                .foregroundStyle(Color.mInk)
                .environment(\.layoutDirection, .leftToRight)

            Spacer()

            Button {
                store.language = store.language == .arabic ? .english : .arabic
            } label: {
                Text(store.language == .arabic ? "English" : "العربية")
                    .font(.plexArabic(11.5, weight: .bold))
                    .foregroundStyle(Color.mAccent800)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.mAccent100)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 6)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.mInkFaint)
            TextField(isArabic ? "ابحث بالرمز أو الاسم... مثال B03" : "Search by code or name... e.g. B03", text: $query)
                .font(.plexArabic(14))
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.mSurface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.mLine, lineWidth: 1))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MFilterChip(label: isArabic ? "الكل" : "All", selected: selectedType == nil) { selectedType = nil }
                ForEach(RestaurantType.allCases, id: \.self) { type in
                    MFilterChip(label: type.label(store.language), selected: selectedType == type) {
                        selectedType = selectedType == type ? nil : type
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.restaurants.isEmpty {
            VStack(spacing: 12) { ForEach(0..<4, id: \.self) { _ in SkeletonRestaurantRow() } }
        } else if let error = store.errorMessage, store.restaurants.isEmpty {
            VStack(spacing: 16) {
                ContentUnavailableView(
                    isArabic ? "خطأ في الاتصال" : "Connection Error",
                    systemImage: "wifi.slash",
                    description: Text(error)
                )
                Button {
                    Task { await store.loadRestaurants() }
                } label: { Text(isArabic ? "المحاولة مجددًا" : "Try Again") }
                    .buttonStyle(.mPrimary(.mAccent, fullWidth: false))
            }
        } else if filtered.isEmpty {
            ContentUnavailableView(
                isArabic ? "لا نتائج" : "No Results",
                systemImage: "fork.knife",
                description: Text(isArabic ? "لا توجد مطاعم بهذا التصنيف" : "No restaurants match this filter")
            )
        } else {
            VStack(spacing: 12) {
                ForEach(filtered) { restaurant in
                    NavigationLink(destination: RestaurantMenuView(restaurant: restaurant)) {
                        RestaurantListRow(restaurant: restaurant, userCoordinate: location.coordinate)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Restaurant Row (list card, matching the customer home mock)

struct RestaurantListRow: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant
    var userCoordinate: CLLocationCoordinate2D?

    private var isArabic: Bool { store.language == .arabic }

    private var placeholderTint: (bg: Color, fg: Color) { restaurant.placeholderTint }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: MTheme.radiusLogo, style: .continuous)
                    .fill(placeholderTint.bg)
                if let urlString = restaurant.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color.clear }
                        .clipShape(RoundedRectangle(cornerRadius: MTheme.radiusLogo, style: .continuous))
                } else {
                    Image(systemName: restaurant.type.icon)
                        .font(.system(size: 30))
                        .foregroundStyle(placeholderTint.fg)
                }
            }
            .frame(width: 84, height: 84)

            // `maxWidth: .infinity` here — not a `Spacer()` alongside it —
            // is what guarantees every row inside (name, type/distance,
            // counts) reaches the exact same right edge flush against the
            // logo: they're all `.trailing`-aligned within ONE block whose
            // own right edge is pinned there, instead of each row sizing
            // to its own content and drifting apart.
            VStack(alignment: .trailing, spacing: 7) {
                HStack(spacing: 6) {
                    Text(restaurant.displayName(store.language))
                        .font(.plexArabicHeavy(16.5))
                        .foregroundStyle(Color.mInk)
                        .lineLimit(1)
                    if let isOpen = restaurant.isOpenNow {
                        MTag(
                            text: isOpen ? (isArabic ? "مفتوح" : "Open") : (isArabic ? "مسكّر" : "Closed"),
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
                .font(.plexArabic(12))
                .foregroundStyle(Color.mInkTertiary)

                Text("\(restaurant.allItems.count) \(isArabic ? "منتج" : "items") · \(restaurant.categories.count) \(isArabic ? "تصنيفات" : "categories")")
                    .font(.plexArabic(11.5))
                    .foregroundStyle(Color.mInkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(13)
        .padding(.leading, 22)
        .mCardStyle()
        .overlay(alignment: .leading) {
            // Independent of the HStack's own flex layout on purpose — an
            // overlay centers vertically by default and never competes with
            // the text block above for the same flexible space.
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.mInkFaint)
                .padding(.leading, 14)
        }
    }
}

// MARK: - Skeleton Row

private struct SkeletonRestaurantRow: View {
    @State private var opacity = 0.45

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 8) {
                Capsule().fill(Color.mSurface2).frame(width: 120, height: 14)
                Capsule().fill(Color.mSurface2).frame(width: 90, height: 11)
                Capsule().fill(Color.mSurface2).frame(width: 70, height: 10)
            }
            RoundedRectangle(cornerRadius: MTheme.radiusLogo, style: .continuous)
                .fill(Color.mSurface2)
                .frame(width: 78, height: 78)
        }
        .padding(14)
        .mCardStyle()
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) { opacity = 1.0 }
        }
    }
}
