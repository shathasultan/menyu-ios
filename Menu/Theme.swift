import SwiftUI
import CoreText

// MARK: - Brand palette (light mode only — matches the "منيو" web prototype 1:1)

extension Color {
    static let mBackground   = Color(hex: 0xF7EEDD)
    static let mSurface      = Color(hex: 0xFFFFFF)
    static let mSurface2     = Color(hex: 0xFBF5E8)
    static let mInk          = Color(hex: 0x241A10)
    static let mInkSoft      = Color(hex: 0x6E5C42)
    static let mInkFaint     = Color(hex: 0x9C8B6E)
    static let mAccent       = Color(hex: 0xD97730)
    static let mAccentStrong = Color(hex: 0xB85D1D)
    static let mAccentInk    = Color(hex: 0xFFFFFF)
    static let mAccentSoft   = Color(hex: 0xF6E2CC)
    static let mGood         = Color(hex: 0x2E8B57)
    static let mGoodSoft     = Color(hex: 0xE4F1E9)
    static let mGoodInk      = Color(hex: 0x1E5E3B)
    static let mBad          = Color(hex: 0xB4432E)
    static let mBadSoft      = Color(hex: 0xF6E2DC)
    static let mLine         = Color(hex: 0xE4D3AE)

    // Deprecated aliases kept temporarily during the identity migration — remove once all call sites move to the m* tokens.
    static let brand      = mAccent
    static let brandLight = mAccentSoft

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Shape / metrics

enum MTheme {
    static let radius: CGFloat = 16
    static let radiusSmall: CGFloat = 10

    static let cardShadow = Color.mInk.opacity(0.08)
}

// MARK: - Typography (IBM Plex Sans Arabic + IBM Plex Mono, bundled in Menu/Fonts)

enum MFontRegistrar {
    static func registerBundledFonts() {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else { return }
        for url in urls {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}

extension Font {
    /// Body/UI text — IBM Plex Sans Arabic.
    static func plexArabic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "IBMPlexSansArabic-Bold"
        case .semibold: name = "IBMPlexSansArabic-SemiBold"
        case .medium: name = "IBMPlexSansArabic-Medium"
        default: name = "IBMPlexSansArabic-Regular"
        }
        return .custom(name, size: size)
    }

    /// Codes, prices, and other numeric/LTR content — IBM Plex Mono.
    static func plexMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "IBMPlexMono-Bold"
        case .semibold: name = "IBMPlexMono-SemiBold"
        default: name = "IBMPlexMono-Medium"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Reusable pieces

/// The product/category code chip (e.g. "A01") — always bold Mono, LTR, isolated from RTL context.
struct CodeChip: View {
    let code: String
    var large: Bool = false

    var body: some View {
        Text(code)
            .font(.plexMono(large ? 20 : 13.5, weight: .bold))
            .foregroundStyle(Color.mAccentStrong)
            .padding(.horizontal, large ? 14 : 9)
            .padding(.vertical, large ? 8 : 5)
            .frame(minWidth: large ? 64 : 40)
            .background(Color.mAccentSoft)
            .clipShape(RoundedRectangle(cornerRadius: large ? 10 : 8, style: .continuous))
            .environment(\.layoutDirection, .leftToRight)
    }
}

/// Standard card surface used across restaurant/product/result rows.
struct MCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.mSurface)
            .clipShape(RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MTheme.radius, style: .continuous)
                    .strokeBorder(Color.mLine, lineWidth: 1)
            )
    }
}

extension View {
    func mCardStyle() -> some View { modifier(MCard()) }
}
