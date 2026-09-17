import SwiftUI

/// Shown once per device, right after Welcome — before any tab is reachable.
/// Routes straight into the app for a plain visitor, or into the vendor
/// sign-in flow for a business owner. See AppStore.skipVendorGateOnce for how
/// the "vendor" choice here skips the in-app VendorIntentGateView too.
struct RoleGateView: View {
    @Environment(AppStore.self) private var store
    var onChooseCustomer: () -> Void
    var onChooseVendor: () -> Void

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        ZStack {
            Color.mBackground.ignoresSafeArea()

            MDecorCircle(diameter: 240, color: .mAccent100, corner: .topLeading, offset: CGSize(width: -190, height: -160))

            VStack(alignment: .trailing, spacing: 0) {
                Text("menu.")
                    .font(.plexMono(26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Color.mInk)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.top, 74)

                Text(isArabic ? "كيف تحب تستخدم menu؟" : "How would you like to use menu?")
                    .font(.plexArabicHeavy(27))
                    .foregroundStyle(Color.mInk)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 18)
                    .padding(.bottom, 6)

                Text(isArabic ? "اختر الوضع المناسب لك، ويمكنك تغييره في أي وقت." : "Pick what fits you — you can change it anytime.")
                    .font(.plexArabic(13.5))
                    .foregroundStyle(Color.mInkSecondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 24)

                VStack(spacing: 14) {
                    roleCard(
                        mascot: .calm,
                        title: isArabic ? "تصفّح القوائم" : "Browse Menus",
                        subtitle: isArabic ? "استعرض المطاعم، وابحث بالرمز، واحفظ اختياراتك المفضلة." : "Explore restaurants, search by code, and save your favorites.",
                        tint: .mAccent, border: .mAccent300,
                        action: onChooseCustomer
                    )
                    roleCard(
                        mascot: .apron,
                        title: isArabic ? "لدي متجر" : "I Have a Store",
                        subtitle: isArabic ? "أضف تصنيفاتك ومنتجاتك، وتُنشأ الرموز تلقائيًا." : "Add your categories and items — codes are generated automatically.",
                        tint: .mSage, border: .mSage300,
                        action: onChooseVendor
                    )
                }

                Spacer(minLength: 24)

                Text(isArabic ? "التصفّح متاح دون تسجيل، والتسجيل مطلوب لأصحاب المتاجر فقط." : "Browsing needs no account — sign-in is only for store owners.")
                    .font(.plexArabic(11.5))
                    .foregroundStyle(Color.mInkFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 22)
        }
    }

    private func roleCard(mascot: MascotVariant, title: String, subtitle: String, tint: Color, border: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                MenyuMascot(variant: mascot, animated: false)
                    .frame(width: 70, height: 83)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(title)
                        .font(.plexArabicHeavy(19))
                        .foregroundStyle(Color.mInk)
                    Text(subtitle)
                        .font(.plexArabic(12.5))
                        .foregroundStyle(Color.mInkSecondary)
                        .multilineTextAlignment(.trailing)
                }

                Circle()
                    .fill(tint)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .padding(20)
            .background(Color.mSurface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(border, lineWidth: 1.5)
            )
            .shadow(color: MTheme.shadowRaised(tint), radius: 20, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}
