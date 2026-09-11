import SwiftUI

/// Shown exactly once per device, right after the first splash — before any tab
/// is reachable. Routes straight into the app for a plain visitor, or into the
/// vendor sign-in flow for a business owner. See AppStore.skipVendorGateOnce for
/// how the "vendor" choice here skips the in-app VendorIntentGateView too.
struct RoleGateView: View {
    @Environment(AppStore.self) private var store
    var onChooseCustomer: () -> Void
    var onChooseVendor: () -> Void

    private var isArabic: Bool { store.language == .arabic }

    var body: some View {
        ZStack {
            Color.mBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)
                    .frame(maxHeight: 90)

                VStack(spacing: 28) {
                    foodIllustration

                    VStack(spacing: 10) {
                        Text(isArabic ? "قبل ما نبدأ" : "Before we start")
                            .font(.plexArabic(21, weight: .bold))
                            .foregroundStyle(Color.mInk)

                        Text(isArabic
                             ? "عندك مطعم أو مقهى أو كشك تبين تديره على منيو، أو بس تتصفحين؟"
                             : "Do you run a restaurant, café, or kiosk you'd like to manage on Menu — or are you just browsing?")
                            .font(.plexArabic(14))
                            .foregroundStyle(Color.mInkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onChooseVendor) {
                        Text(isArabic ? "نعم، عندي مطعم أو مقهى" : "Yes, I have a restaurant or café")
                            .font(.plexArabic(14.5, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(15)
                            .background(Color.mAccent)
                            .foregroundStyle(Color.mAccentInk)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onChooseCustomer) {
                        Text(isArabic ? "لا، أنا زائر فقط" : "No, just browsing")
                            .font(.plexArabic(14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(15)
                            .background(Color.mSurface)
                            .foregroundStyle(Color.mInk)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mLine, lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
        }
    }

    private var foodIllustration: some View {
        HStack(spacing: 18) {
            illustrationTile(icon: "cup.and.saucer.fill", rotation: -8)
            illustrationTile(icon: "takeoutbag.and.cup.and.straw.fill", rotation: 6, larger: true)
            illustrationTile(icon: "fork.knife", rotation: -5)
        }
    }

    private func illustrationTile(icon: String, rotation: Double, larger: Bool = false) -> some View {
        let size: CGFloat = larger ? 86 : 68
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.mAccentSoft)
            Image(systemName: icon)
                .font(.system(size: larger ? 34 : 26))
                .foregroundStyle(Color.mAccentStrong)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(rotation))
    }
}
