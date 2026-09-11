import SwiftUI

struct ContentView: View {
    @State private var store = AppStore()

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(store.language == .arabic ? "الرئيسية" : "Home", systemImage: "house.fill")
                }

            SearchView()
                .tabItem {
                    Label(store.language == .arabic ? "بحث" : "Search", systemImage: "magnifyingglass")
                }

            FavoritesView()
                .tabItem {
                    Label(store.language == .arabic ? "المفضلة" : "Favorites", systemImage: "heart.fill")
                }

            if store.isAuthenticated && !store.myRestaurants.isEmpty {
                OwnerDashboardView()
                    .tabItem {
                        Label(store.language == .arabic ? "لوحتي" : "Dashboard", systemImage: "square.grid.2x2.fill")
                    }
            } else {
                AccountView()
                    .tabItem {
                        Label(store.language == .arabic ? "حسابي" : "Account", systemImage: "person.crop.circle.fill")
                    }
            }

            if store.isAdmin {
                AdminReviewView()
                    .tabItem {
                        Label(store.language == .arabic ? "مراجعة" : "Review", systemImage: "checkmark.seal.fill")
                    }
            }
        }
        .environment(store)
        .environment(\.layoutDirection, store.language == .arabic ? .rightToLeft : .leftToRight)
        .tint(Color.mAccent)
        .preferredColorScheme(.light)
        .background(Color.mBackground)
    }
}

#Preview {
    ContentView()
}
