import SwiftUI

enum AppTab: Hashable {
    case home, search, favorites, account, dashboard, admin
}

struct ContentView: View {
    @State private var store = AppStore()
    @State private var showSplash = true
    @AppStorage("menu.hasCompletedRoleGate.v1") private var hasCompletedRoleGate = false
    @State private var startOnAccountTab = false

    var body: some View {
        Group {
            if showSplash {
                SplashScreenView()
            } else if !hasCompletedRoleGate {
                RoleGateView(
                    onChooseCustomer: { hasCompletedRoleGate = true },
                    onChooseVendor: {
                        store.skipVendorGateOnce = true
                        startOnAccountTab = true
                        hasCompletedRoleGate = true
                    }
                )
            } else {
                MainTabView(startOnAccountTab: startOnAccountTab)
            }
        }
        .environment(store)
        .environment(\.layoutDirection, store.language == .arabic ? .rightToLeft : .leftToRight)
        .tint(Color.mAccent)
        .preferredColorScheme(.light)
        .background(Color.mBackground)
        .task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeInOut(duration: 0.35)) {
                showSplash = false
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: AppTab = .home
    let startOnAccountTab: Bool

    private var isVendor: Bool { store.isAuthenticated && !store.myRestaurants.isEmpty }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(store.language == .arabic ? "الرئيسية" : "Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            SearchView()
                .tabItem {
                    Label(store.language == .arabic ? "بحث" : "Search", systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)

            if !isVendor {
                FavoritesView()
                    .tabItem {
                        Label(store.language == .arabic ? "المفضلة" : "Favorites", systemImage: "heart.fill")
                    }
                    .tag(AppTab.favorites)
            }

            AccountView()
                .tabItem {
                    Label(store.language == .arabic ? "حسابي" : "Account", systemImage: "person.crop.circle.fill")
                }
                .tag(AppTab.account)

            if isVendor {
                OwnerDashboardView()
                    .tabItem {
                        Label(store.language == .arabic ? "لوحتي" : "Dashboard", systemImage: "square.grid.2x2.fill")
                    }
                    .tag(AppTab.dashboard)
            }

            if store.isAdmin {
                AdminReviewView()
                    .tabItem {
                        Label(store.language == .arabic ? "مراجعة" : "Review", systemImage: "checkmark.seal.fill")
                    }
                    .tag(AppTab.admin)
            }
        }
        .onAppear {
            if startOnAccountTab {
                selectedTab = .account
            }
        }
    }
}

#Preview {
    ContentView()
}
