import SwiftUI

/// The tab customers see. Shown instead of the vendor dashboard for anyone who
/// isn't signed in, or who is signed in but doesn't own a restaurant yet — the
/// dashboard tab only appears once `store.myRestaurants` is non-empty (see ContentView).
struct AccountView: View {
    @Environment(AppStore.self) private var store
    @State private var showCreateRestaurant = false

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        NavigationStack {
            Group {
                if !store.isAuthenticated {
                    AccountSignInView()
                } else {
                    List {
                        Section {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color.mAccentSoft).frame(width: 44, height: 44)
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(Color.mAccentStrong)
                                }
                                Text(store.currentUserEmail ?? "")
                                    .font(.plexArabic(14, weight: .medium))
                                    .foregroundStyle(Color.mInk)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.mSurface)

                        Section {
                            Button {
                                showCreateRestaurant = true
                            } label: {
                                Label(
                                    isArabic ? "أنشئي مطعمك الأول" : "Create your first restaurant",
                                    systemImage: "storefront"
                                )
                                .font(.plexArabic(14, weight: .semibold))
                                .foregroundStyle(Color.mAccentStrong)
                            }
                        } footer: {
                            Text(isArabic
                                 ? "عندك مطعم أو مقهى أو كشك؟ أنشئي منيوه من هنا وابدئي إدارته."
                                 : "Have a restaurant, café, or kiosk? Create its menu here to start managing it.")
                                .font(.plexArabic(11.5))
                                .foregroundStyle(Color.mInkFaint)
                        }
                        .listRowBackground(Color.mSurface)

                        Section {
                            Button(role: .destructive) {
                                Task { await store.signOut() }
                            } label: {
                                Text(isArabic ? "تسجيل الخروج" : "Sign Out")
                                    .font(.plexArabic(14, weight: .medium))
                                    .foregroundStyle(Color.mBad)
                            }
                        }
                        .listRowBackground(Color.mSurface)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.mBackground)
                    .sheet(isPresented: $showCreateRestaurant) {
                        CreateRestaurantSheet(onCreated: { _ in })
                    }
                }
            }
            .navigationTitle(isArabic ? "حسابي" : "Account")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Sign In

struct AccountSignInView: View {
    @Environment(AppStore.self) private var store
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorText: String? = nil

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 12)

                // Icon + Title
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.mAccentSoft)
                            .frame(width: 88, height: 88)
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.mAccentStrong)
                    }

                    Text(isArabic ? "حسابي" : "My Account")
                        .font(.plexArabic(19, weight: .bold))
                        .foregroundStyle(Color.mInk)

                    Text(isArabic
                         ? "سجّلي دخولك لحفظ مفضلتك، أو لإنشاء منيو مطعمك"
                         : "Sign in to sync your favorites, or to create your restaurant's menu")
                        .font(.plexArabic(13.5))
                        .foregroundStyle(Color.mInkSoft)
                        .multilineTextAlignment(.center)
                }

                // Form
                VStack(spacing: 12) {
                    TextField(isArabic ? "البريد الإلكتروني" : "Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.plexArabic(14))
                        .padding(14)
                        .background(Color.mSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MTheme.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: MTheme.radiusSmall).strokeBorder(Color.mLine, lineWidth: 1)
                        )

                    SecureField(isArabic ? "كلمة المرور" : "Password", text: $password)
                        .font(.plexArabic(14))
                        .padding(14)
                        .background(Color.mSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MTheme.radiusSmall))
                        .overlay(
                            RoundedRectangle(cornerRadius: MTheme.radiusSmall).strokeBorder(Color.mLine, lineWidth: 1)
                        )
                }

                // Error
                if let errorText {
                    Text(errorText)
                        .font(.plexArabic(12))
                        .foregroundStyle(Color.mBad)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Action button
                Button {
                    Task {
                        isLoading = true
                        errorText = nil
                        do {
                            if isSignUp {
                                try await store.signUp(email: email, password: password)
                            } else {
                                try await store.signIn(email: email, password: password)
                            }
                        } catch {
                            errorText = error.localizedDescription
                        }
                        isLoading = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        }
                        Text(isSignUp
                             ? (isArabic ? "إنشاء حساب" : "Create Account")
                             : (isArabic ? "تسجيل الدخول" : "Sign In"))
                            .font(.plexArabic(14.5, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .background(email.isEmpty || password.isEmpty || isLoading
                                ? Color.mAccent.opacity(0.4) : Color.mAccent)
                    .foregroundStyle(Color.mAccentInk)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(email.isEmpty || password.isEmpty || isLoading)

                // Toggle sign-in / sign-up
                Button {
                    isSignUp.toggle()
                    errorText = nil
                } label: {
                    Text(isSignUp
                         ? (isArabic ? "لديك حساب؟ سجّل الدخول" : "Already have an account? Sign In")
                         : (isArabic ? "لا حساب لديك؟ أنشئ حسابًا" : "No account? Create one"))
                        .font(.plexArabic(13.5))
                        .foregroundStyle(Color.mAccentStrong)
                }

                // Divider
                HStack(spacing: 10) {
                    Rectangle().fill(Color.mLine).frame(height: 1)
                    Text(isArabic ? "أو" : "or")
                        .font(.plexArabic(12))
                        .foregroundStyle(Color.mInkFaint)
                    Rectangle().fill(Color.mLine).frame(height: 1)
                }

                // Google Sign-In
                Button {
                    Task {
                        guard let presenter = AppStore.topViewController() else { return }
                        isLoading = true
                        errorText = nil
                        do {
                            try await store.signInWithGoogle(presenting: presenter)
                        } catch {
                            errorText = error.localizedDescription
                        }
                        isLoading = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "g.circle.fill")
                        Text(isArabic ? "الدخول بحساب قوقل" : "Continue with Google")
                    }
                    .font(.plexArabic(14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.mSurface)
                    .foregroundStyle(Color.mInk)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mLine, lineWidth: 1)
                    )
                }
                .disabled(isLoading)

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 28)
        }
    }
}
