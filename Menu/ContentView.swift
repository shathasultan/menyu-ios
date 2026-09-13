import SwiftUI

enum AppTab: Hashable {
    case home, search, favorites, account
}

enum OwnerTab: Hashable {
    case menu, venue, account
}

private enum OnboardingStep {
    case welcome, role, adminLogin
}

struct ContentView: View {
    @State private var store = AppStore()
    /// Shown on every cold launch, returning users included — only the
    /// Welcome/Role choice below it is a one-time, first-launch-only step.
    @State private var showSplash = true
    @State private var step: OnboardingStep = .welcome
    @AppStorage("menu.hasCompletedRoleGate.v1") private var hasCompletedRoleGate = false
    @State private var startOnAccountTab = false

    private var isVendor: Bool { store.isAuthenticated && !store.myRestaurants.isEmpty }

    var body: some View {
        Group {
            if showSplash {
                SplashScreenView(onFinished: {
                    withAnimation(.easeInOut(duration: 0.3)) { showSplash = false }
                })
            } else if hasCompletedRoleGate {
                if store.isAdmin {
                    AdminReviewView()
                } else if isVendor {
                    OwnerDashboardShell()
                } else {
                    CustomerTabView(startOnAccountTab: startOnAccountTab)
                }
            } else {
                onboarding
            }
        }
        // Rebuilds this entire subtree — including every UIKit control
        // TabView/NavigationStack bridge in underneath — from scratch
        // whenever the language changes. `.environment(\.layoutDirection)`
        // alone only mirrors pure-SwiftUI content; already-instantiated
        // UIKit view controllers (tab bar order, nav bar chrome) don't
        // retroactively re-read it. Forcing a fresh identity guarantees
        // every UIKit view is created AFTER `applyWindowDirection()` below
        // has set the correct `semanticContentAttribute`, so nothing is
        // ever left over from a previous language.
        .id(store.language)
        .environment(store)
        .environment(\.layoutDirection, store.language == .arabic ? .rightToLeft : .leftToRight)
        .tint(Color.mAccent)
        .preferredColorScheme(.light)
        .background(Color.mBackground)
        .onAppear { applyWindowDirection() }
        .onChange(of: store.language) { _, _ in applyWindowDirection() }
    }

    /// SwiftUI's `.environment(\.layoutDirection, …)` mirrors pure-SwiftUI
    /// content, but the UIKit chrome bridged in underneath (`TabView`'s
    /// `UITabBarController`, `NavigationStack`'s `UINavigationController` —
    /// tab order, back-swipe edge, nav bar item placement) instead follows
    /// each `UIView`'s own `semanticContentAttribute`. Update BOTH the
    /// global appearance-proxy default (so every UIKit view created from
    /// here on — including ones instantiated deep inside a freshly
    /// `.id()`-rebuilt TabView/NavigationStack — picks up the right value
    /// with no static default left over from launch) and every live
    /// window, so this only ever reflects `store.language`, never the
    /// device's own system language.
    private func applyWindowDirection() {
        let attribute: UISemanticContentAttribute = store.language == .arabic ? .forceRightToLeft : .forceLeftToRight
        UIView.appearance().semanticContentAttribute = attribute
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.semanticContentAttribute = attribute
                window.rootViewController?.view.semanticContentAttribute = attribute
            }
        }
    }

    @ViewBuilder
    private var onboarding: some View {
        switch step {
        case .welcome:
            WelcomeView(
                onStart: { withAnimation(.easeOut(duration: 0.3)) { step = .role } },
                onAdminLogin: { step = .adminLogin }
            )
        case .role:
            RoleGateView(
                onChooseCustomer: { hasCompletedRoleGate = true },
                onChooseVendor: {
                    store.skipVendorGateOnce = true
                    startOnAccountTab = true
                    hasCompletedRoleGate = true
                }
            )
        case .adminLogin:
            AdminLoginView(
                onBack: { step = .welcome },
                onSuccess: { hasCompletedRoleGate = true }
            )
        }
    }
}

/// The customer-facing tab bar — browsing, search, favorites, and the
/// account tab (which doubles as the vendor sign-in gate). Shown to anyone
/// who isn't signed in, or who is signed in but doesn't yet own a
/// restaurant. The moment `myRestaurants` becomes non-empty, ContentView
/// swaps this whole tab bar for `OwnerDashboardShell` — the two modes never
/// show their tabs side by side, matching the design's separate `app/owner`
/// vs `app/customer` navigation graphs.
struct CustomerTabView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedTab: AppTab = .home
    let startOnAccountTab: Bool

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(isArabic ? "الرئيسية" : "Home", systemImage: "house.fill") }
                .tag(AppTab.home)

            SearchView()
                .tabItem { Label(isArabic ? "بحث" : "Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)

            FavoritesView()
                .tabItem { Label(isArabic ? "مفضلاتي" : "Favorites", systemImage: "heart.fill") }
                .tag(AppTab.favorites)

            AccountView()
                .tabItem { Label(isArabic ? "حسابي" : "Account", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.account)
        }
        .tint(Color.mAccent800)
        .onAppear {
            if startOnAccountTab { selectedTab = .account }
        }
    }
}

#Preview {
    ContentView()
}
