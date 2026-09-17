import SwiftUI

/// The three-line explainer shown once, right after Splash — before Role.
struct WelcomeView: View {
    @Environment(AppStore.self) private var store
    var onStart: () -> Void
    var onAdminLogin: () -> Void

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        ZStack {
            Color.mBackground.ignoresSafeArea()

            MDecorCircle(diameter: 300, color: .mAccent100, corner: .topTrailing, offset: CGSize(width: 180, height: -180))
            MDecorCircle(diameter: 170, color: .mSage100, corner: .topLeading, offset: CGSize(width: -115, height: 105))

            VStack(spacing: 0) {
                MenyuMascot(variant: .default, bobDuration: 3.4)
                    .frame(width: 150, height: 178)
                    .padding(.top, 90)

                Spacer(minLength: 20)

                VStack(alignment: .trailing, spacing: 16) {
                    Text("menu.")
                        .font(.plexMono(30, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundStyle(Color.mInk)
                        .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                        .environment(\.layoutDirection, .leftToRight)

                    Text(isArabic ? "أهلًا بك في menu" : "Welcome to menu")
                        .font(.plexArabicHeavy(30))
                        .foregroundStyle(Color.mInk)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    (
                        Text(isArabic
                             ? "قوائم المطاعم كلها في مكان واحد، ولكل منتج رمز ثابت يختصر الطلب: اطلب "
                             : "Every restaurant's menu in one place, and every item carries a permanent code that shortens the order: order ")
                        + Text("B03").foregroundStyle(Color.mAccent800).fontWeight(.bold)
                        + Text(isArabic ? " بدلًا من الاسم الطويل." : " instead of the long name.")
                    )
                    .font(.plexArabic(14))
                    .foregroundStyle(Color.mInkSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineSpacing(4)

                    VStack(alignment: .trailing, spacing: 11) {
                        numberedPoint(1, isArabic
                            ? "تصفّح المطاعم والمقاهي القريبة بقوائم محدّثة لحظيًا."
                            : "Browse nearby restaurants and cafés with menus updated live.")
                        numberedPoint(2, isArabic
                            ? "ابحث بالرمز، مثل A01 أو B03، بدلًا من الأسماء الطويلة."
                            : "Search by code, like A01 or B03, instead of long names.")
                        numberedPoint(3, isArabic
                            ? "لديك متجر؟ سجّل حسابك، وأضف قائمتك، وانشرها بعد اعتماد الإدارة."
                            : "Have a store? Sign up, add your menu, and publish it after admin approval.")
                    }
                }
                .padding(.bottom, 26)

                Button(action: onStart) {
                    Text(isArabic ? "ابدأ الآن" : "Get Started")
                }
                .buttonStyle(.mPrimary())

                Button(action: onAdminLogin) {
                    Text(isArabic ? "دخول الإدارة" : "Admin Login")
                        .font(.plexArabic(12, weight: .bold))
                        .foregroundStyle(Color.mInkMuted)
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 34)
            .mUpEntry()
        }
    }

    private func numberedPoint(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(text)
                .font(.plexArabic(13))
                .foregroundStyle(Color.mInk.opacity(0.7))
                .multilineTextAlignment(.trailing)
                .lineSpacing(3)
            Text("\(n)")
                .font(.plexMono(12, weight: .heavy))
                .foregroundStyle(Color.mAccent800)
                .frame(width: 30, height: 30)
                .background(Color.mAccent100)
                .clipShape(Circle())
        }
    }
}

#Preview {
    WelcomeView(onStart: {}, onAdminLogin: {})
        .environment(AppStore())
}
