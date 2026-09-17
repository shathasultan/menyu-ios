import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

/// The tab customers see. Shown for anyone who isn't signed in, or who is
/// signed in but doesn't own a restaurant yet — the moment `myRestaurants`
/// is non-empty, ContentView swaps the whole tab bar for
/// `OwnerDashboardShell`, which owns the authenticated-vendor experience
/// (My Store / Account tabs) from then on. This screen only ever shows the
/// pre-vendor states: the intent gate, sign-in, or "create your first
/// restaurant" once signed in with nothing yet.
struct AccountView: View {
    @Environment(AppStore.self) private var store
    @State private var showCreateRestaurant = false
    @State private var confirmedVendorIntent = false
    @State private var showAdminLogin = false

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        NavigationStack {
            Group {
                if !store.isAuthenticated {
                    if confirmedVendorIntent {
                        AccountSignInView(onAdminLogin: { showAdminLogin = true })
                    } else {
                        VendorIntentGateView(onConfirm: { confirmedVendorIntent = true }, onAdminLogin: { showAdminLogin = true })
                    }
                } else {
                    createFirstRestaurantView
                }
            }
            .navigationTitle(isArabic ? "حسابي" : "Account")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            if store.skipVendorGateOnce {
                confirmedVendorIntent = true
                store.skipVendorGateOnce = false
            }
        }
        .fullScreenCover(isPresented: $showAdminLogin) {
            AdminLoginView(onBack: { showAdminLogin = false }, onSuccess: { showAdminLogin = false })
        }
    }

    private var createFirstRestaurantView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)
                ZStack {
                    Circle().fill(Color.mSage100).frame(width: 88, height: 88)
                    Image(systemName: "storefront.fill").font(.system(size: 34)).foregroundStyle(Color.mSage800)
                }
                VStack(spacing: 8) {
                    Text(isArabic ? "أنشئي مطعمك الأول" : "Create Your First Restaurant")
                        .font(.plexArabicHeavy(18))
                        .multilineTextAlignment(.center)
                    Text(isArabic ? "عندك مطعم أو مقهى أو كشك؟ أنشئي منيوه من هنا وابدئي إدارته." : "Have a restaurant, café, or kiosk? Create its menu here to start managing it.")
                        .font(.plexArabic(13.5))
                        .foregroundStyle(Color.mInkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                Button { showCreateRestaurant = true } label: {
                    Text(isArabic ? "إنشاء مطعم" : "Create Restaurant")
                }
                .buttonStyle(.mPrimary(.mSage))
                .padding(.horizontal, 28)

                Button {
                    Task { await store.signOut() }
                } label: {
                    Text(isArabic ? "تسجيل الخروج" : "Sign Out")
                }
                .buttonStyle(.mSecondary())
                .padding(.horizontal, 28)

                Spacer().frame(height: 20)
            }
        }
        .sheet(isPresented: $showCreateRestaurant) {
            CreateRestaurantSheet(onCreated: { newID in store.selectedRestaurantID = newID })
        }
    }
}

// MARK: - Vendor Intent Gate

/// Sits in front of the sign-in form. Browsing and favorites never need an account —
/// the only reason to sign in today is to manage a restaurant — so this makes that
/// explicit before showing any auth UI, instead of a generic "Account" screen that
/// invites anyone to sign in without a reason to.
struct VendorIntentGateView: View {
    @Environment(AppStore.self) private var store
    /// Same key ContentView routes on. The role screen promises "you can change
    /// it anytime", and this is what makes that true — before, the flag was set
    /// once on first launch and nothing could ever unset it.
    @AppStorage("menu.hasCompletedRoleGate.v1") private var hasCompletedRoleGate = false
    var onConfirm: () -> Void
    var onAdminLogin: (() -> Void)? = nil

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 24)

                ZStack {
                    Circle().fill(Color.mSage100).frame(width: 88, height: 88)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.mSage800)
                }

                VStack(spacing: 10) {
                    Text(isArabic ? "هذا القسم لأصحاب الأعمال" : "This section is for business owners")
                        .font(.plexArabicHeavy(18))
                        .foregroundStyle(Color.mInk)
                        .multilineTextAlignment(.center)

                    Text(isArabic
                         ? "تصفّح المطاعم وحفظ المفضلة لا يحتاجان تسجيل دخول إطلاقًا. تسجيل الدخول هنا فقط لمن عنده مطعم أو مقهى أو كشك يبي يديره."
                         : "Browsing and favorites never need an account. Signing in here is only for managing a restaurant, café, or kiosk.")
                        .font(.plexArabic(13.5))
                        .foregroundStyle(Color.mInkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                Button(action: onConfirm) {
                    Text(isArabic ? "نعم، عندي مطعم أو مقهى" : "Yes, I have a restaurant or café")
                }
                .buttonStyle(.mPrimary(.mSage))
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Button {
                    hasCompletedRoleGate = false
                } label: {
                    Text(isArabic ? "تغيير طريقة الاستخدام" : "Change how you use menu")
                        .font(.plexArabic(12, weight: .bold))
                        .foregroundStyle(Color.mInkMuted)
                }

                if let onAdminLogin {
                    Button(action: onAdminLogin) {
                        Text(isArabic ? "دخول الإدارة" : "Admin Login")
                            .font(.plexArabic(12, weight: .bold))
                            .foregroundStyle(Color.mInkMuted)
                    }
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Sign In

/// Google and Apple. No email/password, no phone number anywhere in the
/// merchant profile — a merchant's identity is just the email the provider
/// hands back, and nothing else is collected at sign-in time.
///
/// Apple is not optional here: `AppStore.signInWithApple` and the
/// `com.apple.developer.applesignin` entitlement were both already in place,
/// but no screen ever presented the button. App Store Review Guideline 4.8
/// requires an equivalent login option wherever a third-party sign-in like
/// Google is offered, so shipping without this button is a rejection.
struct AccountSignInView: View {
    @Environment(AppStore.self) private var store
    @State private var isLoading = false
    @State private var errorText: String? = nil
    /// The admin entrance used to live only on the intent gate before it, so
    /// confirming "yes, I have a restaurant" hid it for the rest of the
    /// session, and Welcome — the only other way in — shows once per device.
    var onAdminLogin: (() -> Void)? = nil

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                VStack(spacing: 12) {
                    MenyuMascot(variant: .apron, bobDuration: 3.6)
                        .frame(width: 70, height: 83)

                    Text(isArabic ? "تسجيل الدخول" : "Sign In")
                        .font(.plexArabicHeavy(19))
                        .foregroundStyle(Color.mInk)

                    Text(isArabic ? "سجّل الدخول بحساب Google لإدارة قائمتك." : "Sign in with Google to manage your menu.")
                        .font(.plexArabic(13.5))
                        .foregroundStyle(Color.mInkSecondary)
                        .multilineTextAlignment(.center)
                }

                if let errorText {
                    Text(errorText)
                        .font(.plexArabic(12))
                        .foregroundStyle(Color.mAccent800)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.mAccent100)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                // Google's own button from `GoogleSignInSwift`, which ships
                // with the package already linked to this target. Their
                // sign-in branding guidelines require their supplied mark and
                // button, so this is the one control in the app that is
                // deliberately not in our design language — a close-enough
                // lookalike is grounds for rejection.
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    GoogleSignInButton {
                        Task {
                            guard let presenter = AppStore.topViewController() else { return }
                            isLoading = true
                            errorText = nil
                            do { try await store.signInWithGoogle(presenting: presenter) }
                            catch { errorText = store.signInFailureText(error, arabic: isArabic) }
                            isLoading = false
                        }
                    }
                    .frame(height: 52)
                }

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.email]
                    request.nonce = store.makeAppleNonce()
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        Task {
                            isLoading = true
                            errorText = nil
                            do { try await store.signInWithApple(authorization: authorization) }
                            catch { errorText = store.signInFailureText(error, arabic: isArabic) }
                            isLoading = false
                        }
                    case .failure(let error):
                        // Backing out of the sheet is not a failure to report;
                        // signInFailureText returns nil for that.
                        errorText = store.signInFailureText(error, arabic: isArabic)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(Capsule())
                .disabled(isLoading)

                Text(isArabic ? "تراجع إدارة menu حسابك قبل ظهور متجرك للعملاء." : "menu's admin reviews your account before your store appears to customers.")
                    .font(.plexArabic(11.5))
                    .foregroundStyle(Color.mInkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                if let onAdminLogin {
                    Button(action: onAdminLogin) {
                        Text(isArabic ? "دخول الإدارة" : "Admin Login")
                            .font(.plexArabic(12, weight: .bold))
                            .foregroundStyle(Color.mInkMuted)
                    }
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 28)
        }
    }
}
