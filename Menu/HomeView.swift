import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedType: RestaurantType? = nil

    var filtered: [Restaurant] {
        guard let type = selectedType else { return store.restaurants }
        return store.restaurants.filter { $0.type == type }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    filterChips

                    // Section header
                    HStack {
                        Text(store.language == .arabic ? "المطاعم والمقاهي" : "Restaurants & Cafés")
                            .font(.plexArabic(15, weight: .bold))
                            .foregroundStyle(Color.mInk)
                        Spacer()
                        if !store.isLoading {
                            Text("\(filtered.count)")
                                .font(.plexMono(12, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.mSurface2)
                                .foregroundStyle(Color.mInkSoft)
                                .clipShape(Capsule())
                                .environment(\.layoutDirection, .leftToRight)
                        }
                    }
                    .padding(.horizontal)

                    // Grid content
                    if store.isLoading && store.restaurants.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(0..<6, id: \.self) { _ in SkeletonRestaurantCard() }
                        }
                        .padding(.horizontal)
                    } else if let error = store.errorMessage, store.restaurants.isEmpty {
                        VStack(spacing: 16) {
                            ContentUnavailableView(
                                store.language == .arabic ? "خطأ في الاتصال" : "Connection Error",
                                systemImage: "wifi.slash",
                                description: Text(error)
                            )
                            Button {
                                Task { await store.loadRestaurants() }
                            } label: {
                                Text(store.language == .arabic ? "المحاولة مجددًا" : "Try Again")
                                    .font(.plexArabic(14.5, weight: .semibold))
                                    .padding(.horizontal, 24).padding(.vertical, 10)
                                    .background(Color.mAccent)
                                    .foregroundStyle(Color.mAccentInk)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    } else if filtered.isEmpty {
                        ContentUnavailableView(
                            store.language == .arabic ? "لا نتائج" : "No Results",
                            systemImage: "fork.knife",
                            description: Text(store.language == .arabic
                                ? "لا توجد مطاعم بهذا التصنيف"
                                : "No restaurants match this filter")
                        )
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(filtered) { restaurant in
                                NavigationLink(destination: RestaurantMenuView(restaurant: restaurant)) {
                                    RestaurantCard(restaurant: restaurant)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                .padding(.top, 12)
            }
            .background(Color.mBackground)
            .refreshable { await store.loadRestaurants() }
            .navigationTitle(store.language == .arabic ? "منيو" : "Menū")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.language = store.language == .arabic ? .english : .arabic
                    } label: {
                        Text(store.language == .arabic ? "EN" : "ع")
                            .font(.plexMono(14, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(Color.mAccentSoft)
                            .foregroundStyle(Color.mAccentStrong)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: store.language == .arabic ? "الكل" : "All",
                    isSelected: selectedType == nil
                ) { selectedType = nil }

                ForEach(RestaurantType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.label(store.language),
                        icon: type.icon,
                        isSelected: selectedType == type
                    ) {
                        selectedType = selectedType == type ? nil : type
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.caption)
                }
                Text(title)
                    .font(.plexArabic(13, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.mInk : Color.mSurface)
            .foregroundStyle(isSelected ? Color.mBackground : Color.mInkSoft)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : Color.mLine, lineWidth: 1)
            )
        }
    }
}

// MARK: - Restaurant Card

struct RestaurantCard: View {
    @Environment(AppStore.self) private var store
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let urlString = restaurant.imageURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.mAccentSoft
                    }
                } else {
                    Color.mAccentSoft
                    Image(systemName: restaurant.type.icon)
                        .font(.system(size: 34))
                        .foregroundStyle(Color.mAccentStrong)
                }
            }
            .frame(height: 88)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(restaurant.displayName(store.language))
                    .font(.plexArabic(14.5, weight: .bold))
                    .lineLimit(1).foregroundStyle(Color.mInk)

                HStack(spacing: 3) {
                    Image(systemName: restaurant.type.icon).font(.system(size: 9))
                    Text(restaurant.type.label(store.language))
                        .font(.plexArabic(11, weight: .semibold))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.mAccentSoft)
                .foregroundStyle(Color.mAccentStrong)
                .clipShape(Capsule())

                Text("\(restaurant.allItems.count) \(store.language == .arabic ? "منتج" : "items")")
                    .font(.plexArabic(11))
                    .foregroundStyle(Color.mInkFaint)
            }
            .padding(12)
        }
        .mCardStyle()
    }
}

// MARK: - Skeleton Card

private struct SkeletonRestaurantCard: View {
    @State private var opacity = 0.45

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.mSurface2.frame(height: 88)

            VStack(alignment: .leading, spacing: 8) {
                Capsule()
                    .fill(Color.mSurface2)
                    .frame(height: 13)
                    .padding(.trailing, 28)

                HStack(spacing: 0) {
                    Capsule()
                        .fill(Color.mSurface2)
                        .frame(width: 56, height: 18)
                    Spacer()
                }

                Capsule()
                    .fill(Color.mSurface2)
                    .frame(width: 48, height: 10)
            }
            .padding(12)
        }
        .mCardStyle()
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}
