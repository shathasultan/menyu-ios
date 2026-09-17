import SwiftUI

/// Dedicated, visually-inverted entry point for platform staff — reachable
/// from Welcome's "دخول الإدارة" link (and, after onboarding is complete,
/// from a small link on AccountView's pre-auth screen, since Welcome only
/// ever shows once per device). Uses the same `AppStore.isAdmin` hardcoded-
/// email check as before, just as its own real screen instead of an
/// auto-appearing tab.
struct AdminLoginView: View {
    @Environment(AppStore.self) private var store
    var onBack: () -> Void
    var onSuccess: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var error: String?
    @State private var submitting = false

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        ZStack {
            Color.mAdminBg.ignoresSafeArea()

            MDecorCircle(diameter: 240, color: .white.opacity(0.05), corner: .bottomLeading, offset: CGSize(width: -170, height: 170))

            VStack(alignment: .trailing, spacing: 0) {
                Button(action: onBack) {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .overlay(Circle().strokeBorder(Color.mAdminBorder, lineWidth: 1))
                }
                .padding(.top, 60)
                .padding(.bottom, 22)

                HStack(spacing: 8) {
                    Text(isArabic ? "الإدارة" : "Admin")
                        .font(.plexArabic(12, weight: .bold))
                        .foregroundStyle(Color.mAdminTextSecondary)
                    Text("menu.")
                        .font(.plexMono(26, weight: .heavy))
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.bottom, 20)

                Text(isArabic ? "لوحة الأدمن" : "Admin Panel")
                    .font(.plexArabicHeavy(25))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 8)

                Text(isArabic ? "الدخول مخصص لبريد الإدارة، ومنه تُعتمد طلبات المطاعم." : "Access is limited to the admin email — restaurant requests are reviewed from here.")
                    .font(.plexArabic(12.5))
                    .foregroundStyle(Color.mAdminTextSecondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 26)

                VStack(spacing: 10) {
                    adminField(isArabic ? "بريد الإدارة" : "Admin email", text: $email, keyboard: .emailAddress)
                    adminField(isArabic ? "كلمة المرور" : "Password", text: $password, secure: true)
                }
                .padding(.bottom, 12)

                if let error {
                    Text(error)
                        .font(.plexArabic(12))
                        .foregroundStyle(Color.mAccent300)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.bottom, 14)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if submitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(isArabic ? "دخول" : "Sign In")
                    }
                }
                .buttonStyle(.mPrimary())
                .disabled(submitting || email.isEmpty || password.isEmpty)

                // This screen only accepted a password, but an admin account
                // created through Google has none — its owner could never get
                // in here, only through the customer Account tab. Same gate
                // either way: sign in, then `is_admin()` decides.
                Button {
                    Task { await submitWithGoogle() }
                } label: {
                    Text(isArabic ? "الدخول بحساب Google بدلًا من ذلك" : "Use Google instead")
                        .font(.plexArabic(12, weight: .bold))
                        .foregroundStyle(Color.mAdminTextSecondary)
                }
                .disabled(submitting)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)
            }
            .padding(.horizontal, 22)
        }
    }

    private func adminField(_ placeholder: String, text: Binding<String>, secure: Bool = false, keyboard: UIKeyboardType = .default) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .autocapitalization(.none)
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.trailing)
            }
        }
        .font(.plexArabic(14))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.mAdminSurface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.mAdminBorder, lineWidth: 1))
    }

    private func submit() async {
        error = nil
        submitting = true
        defer { submitting = false }
        do {
            try await store.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            await finishIfAdmin()
        } catch {
            self.error = store.signInFailureText(error, arabic: isArabic)
        }
    }

    private func submitWithGoogle() async {
        error = nil
        guard let presenter = AppStore.topViewController() else { return }
        submitting = true
        defer { submitting = false }
        do {
            try await store.signInWithGoogle(presenting: presenter)
            await finishIfAdmin()
        } catch {
            self.error = store.signInFailureText(error, arabic: isArabic)
        }
    }

    /// `store.isAdmin` is answered by `public.is_admin()` during `checkSession`,
    /// which both sign-in paths call — so this reads the database's answer, not
    /// a list of emails inside the app.
    private func finishIfAdmin() async {
        if store.isAdmin {
            onSuccess()
        } else {
            await store.signOut()
            error = isArabic ? "هذا الحساب لا يملك صلاحية الإدارة." : "This account doesn't have admin access."
        }
    }
}

#Preview {
    AdminLoginView(onBack: {}, onSuccess: {})
        .environment(AppStore())
}
