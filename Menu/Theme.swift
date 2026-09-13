import SwiftUI
import CoreText

// MARK: - Brand palette ("Organic" — terracotta for customer flows, sage for
// merchant flows, from the Claude Design handoff. Light mode only.)

extension Color {
    static let mBackground   = Color(hex: 0xFFFFFF)
    static let mCream        = Color(hex: 0xF5EAD8)
    static let mSurface      = Color(hex: 0xFFFFFF)
    static let mSurface2     = Color(hex: 0xFDF9F3)
    static let mInk          = Color(hex: 0x201E1D)

    // Alpha ink ramp, derived from mInk per the handoff's token table.
    static let mInkSecondary = Color.mInk.opacity(0.55)
    static let mInkTertiary  = Color.mInk.opacity(0.50)
    static let mInkMuted     = Color.mInk.opacity(0.42)
    static let mInkFaint     = Color.mInk.opacity(0.40)
    static let mInkInactive  = Color.mInk.opacity(0.35)
    static let mLine         = Color.mInk.opacity(0.12)
    static let mHairline     = Color.mInk.opacity(0.08)
    static let mChipFill     = Color.mInk.opacity(0.06)

    /// Terracotta — customer-side primary: CTAs, codes, active customer tab.
    static let mAccent    = Color(hex: 0xC67139)
    static let mAccent100 = Color(hex: 0xFFF2EB)
    static let mAccent200 = Color(hex: 0xFFE1D0)
    static let mAccent300 = Color(hex: 0xFFC6A5)
    static let mAccent400 = Color(hex: 0xF6A06B)
    static let mAccent500 = Color(hex: 0xD67F48)
    static let mAccent600 = Color(hex: 0xB2622D)
    static let mAccent700 = Color(hex: 0x8C491A)
    static let mAccent800 = Color(hex: 0x643312)
    static let mAccent900 = Color(hex: 0x402310)

    /// Sage — merchant/owner-side primary: owner header, "available", approve.
    static let mSage    = Color(hex: 0x7A8A5E)
    static let mSage100 = Color(hex: 0xF0FAE1)
    static let mSage200 = Color(hex: 0xE1EECC)
    static let mSage300 = Color(hex: 0xCCDBB2)
    static let mSage400 = Color(hex: 0xAEBF92)
    static let mSage500 = Color(hex: 0x8FA073)
    static let mSage600 = Color(hex: 0x728157)
    static let mSage700 = Color(hex: 0x56633F)
    static let mSage800 = Color(hex: 0x3D472B)
    static let mSage900 = Color(hex: 0x272E1B)

    // Dark admin surface (near-black background, white/ink-inverted text).
    static let mAdminBg           = Color.mInk
    static let mAdminSurface      = Color.white.opacity(0.08)
    static let mAdminSurfaceLight = Color.white.opacity(0.06)
    static let mAdminBorder       = Color.white.opacity(0.18)
    static let mAdminTextSecondary = Color.white.opacity(0.55)
    static let mAdminTextTertiary  = Color.white.opacity(0.60)

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
    /// Standard card corner radius (spec range 20–28).
    static let radius: CGFloat = 22
    /// Logo/photo tile corner radius (spec range 14–26).
    static let radiusLogo: CGFloat = 20
    /// Small inline elements (category letter badge, stat tile, etc).
    static let radiusSmall: CGFloat = 14

    // Shadows — tuned to the ground per the handoff's shadow tokens.
    static let shadowCard = Color.mInk.opacity(0.05)
    static func shadowRaised(_ tint: Color) -> Color { tint.opacity(0.10) }
    static func shadowCTA(_ tint: Color, strength: Double = 0.26) -> Color { tint.opacity(strength) }
}

// MARK: - Typography (Almarai + Figtree, bundled in Menu/Fonts)

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
    /// Body/UI text — Almarai. Only ships 400/700/800, so medium/semibold fall
    /// back to the nearest available weight.
    static func plexArabic(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black, .semibold: name = "Almarai-Bold"
        case .medium: name = "Almarai-Regular"
        default: name = "Almarai-Regular"
        }
        return .custom(name, size: size)
    }

    /// A dedicated hook for the handoff's 800-weight ("ExtraBold") Almarai —
    /// used for headings/titles/wordmark-adjacent Arabic text.
    static func plexArabicHeavy(_ size: CGFloat) -> Font {
        .custom("Almarai-ExtraBold", size: size)
    }

    /// Codes, prices, and other numeric/LTR content — Figtree.
    static func plexMono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let name: String
        switch weight {
        case .heavy, .black: name = "Figtree-ExtraBold"
        case .bold: name = "Figtree-Bold"
        case .semibold: name = "Figtree-SemiBold"
        case .medium: name = "Figtree-Medium"
        default: name = "Figtree-Regular"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Reusable pieces

/// The product/category code chip (e.g. "A01") — always bold Figtree, LTR,
/// isolated from RTL context. Terracotta on customer surfaces by default;
/// pass `tint: .mSage` on owner-side surfaces.
struct CodeChip: View {
    let code: String
    var large: Bool = false
    var tint: Color = .mAccent

    var body: some View {
        Text(code)
            .font(.plexMono(large ? 26 : 15, weight: .heavy))
            .tracking(-0.3)
            .foregroundStyle(tint)
            .frame(minWidth: large ? 64 : 52, alignment: .center)
            .environment(\.layoutDirection, .leftToRight)
    }
}

/// Standard card surface used across restaurant/product/result rows.
struct MCard: ViewModifier {
    var radius: CGFloat = MTheme.radius
    func body(content: Content) -> some View {
        content
            .background(Color.mSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.mHairline, lineWidth: 1)
            )
            .shadow(color: MTheme.shadowCard, radius: 10, x: 0, y: 2)
    }
}

extension View {
    func mCardStyle(radius: CGFloat = MTheme.radius) -> some View { modifier(MCard(radius: radius)) }
}

/// Brand-styled pill text input used across every form — replaces the default
/// system-grey `Form`/`TextField` look with the app's own surface/line tokens.
struct MTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.plexArabic(14))
            .padding(.horizontal, 17)
            .padding(.vertical, 13)
            .background(Color.mSurface)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.mLine, lineWidth: 1))
    }
}

extension View {
    func mFieldStyle() -> some View { modifier(MTextFieldStyle()) }
}

/// A labeled field wrapper (label above input) used throughout every form, so
/// every screen reads consistently instead of a bare `Form`.
struct MFormField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.plexArabic(11.5, weight: .bold))
                .foregroundStyle(Color.mInkTertiary)
                .padding(.horizontal, 4)
            content
        }
    }
}

/// Sheet chrome (title + Cancel/primary action) matching the brand instead of
/// the default system nav-bar text-button look, used by every form sheet.
struct MSheetToolbar: ToolbarContent {
    let isArabic: Bool
    let cancelTitle: String
    let actionTitle: String
    let actionDisabled: Bool
    var tint: Color = .mAccent800
    let onCancel: () -> Void
    let onAction: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(cancelTitle, action: onCancel)
                .font(.plexArabic(14))
                .foregroundStyle(Color.mInkSecondary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(actionTitle, action: onAction)
                .font(.plexArabic(14, weight: .bold))
                .foregroundStyle(actionDisabled ? Color.mInkFaint : tint)
                .disabled(actionDisabled)
        }
    }
}

// MARK: - Buttons

/// Full-width pill primary button. `tint` picks the role color: `.mAccent`
/// (terracotta) on customer surfaces, `.mSage` on merchant/owner surfaces.
struct MPrimaryButtonStyle: ButtonStyle {
    var tint: Color = .mAccent
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.plexArabic(15.5, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(configuration.isPressed ? tint.opacity(0.85) : tint)
            .clipShape(Capsule())
            .shadow(color: MTheme.shadowCTA(tint), radius: 16, x: 0, y: 8)
    }
}

/// Outlined pill secondary button.
struct MSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.plexArabic(14.5, weight: .bold))
            .foregroundStyle(Color.mInkSecondary)
            .padding(.vertical, 14)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(configuration.isPressed ? Color.mChipFill : Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.mLine, lineWidth: 1))
    }
}

extension ButtonStyle where Self == MPrimaryButtonStyle {
    static func mPrimary(_ tint: Color = .mAccent, fullWidth: Bool = true) -> MPrimaryButtonStyle {
        MPrimaryButtonStyle(tint: tint, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == MSecondaryButtonStyle {
    static func mSecondary(fullWidth: Bool = true) -> MSecondaryButtonStyle { MSecondaryButtonStyle(fullWidth: fullWidth) }
}

// MARK: - Chips / tags / segmented control

/// A generic pill tag — replaces the type-badge/status-badge code that was
/// hand-rolled per screen. Two tints: `.tinted` (light fill / dark-on-tint
/// text from the given color's 100/800 pair) or `.solid` (dark ink fill).
struct MTag: View {
    enum Style { case tinted(Color, Color), neutral, solidInk }
    let text: String
    var icon: String? = nil
    var style: Style = .neutral

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .bold)) }
            Text(text).font(.plexArabic(10.5, weight: .bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(background)
        .foregroundStyle(foreground)
        .clipShape(Capsule())
    }

    private var background: Color {
        switch style {
        case .tinted(let bg, _): return bg
        case .neutral: return Color.mChipFill
        case .solidInk: return Color.mInk
        }
    }
    private var foreground: Color {
        switch style {
        case .tinted(_, let fg): return fg
        case .neutral: return Color.mInkSecondary
        case .solidInk: return .white
        }
    }
}

/// Horizontally-scrolling pill filter/category chip row entry.
struct MFilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.plexArabic(12.5, weight: .bold))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? Color.mInk : Color.mSurface)
                .foregroundStyle(selected ? Color.white : Color.mInk)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(selected ? Color.clear : Color.mLine, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Two-option pill segmented control (e.g. "تسجيل دخول" / "حساب جديد").
struct MSegmentedControl: View {
    let options: [String]
    @Binding var selection: Int
    var tint: Color = .mInk

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = i }
                } label: {
                    Text(options[i])
                        .font(.plexArabic(13, weight: .bold))
                        .foregroundStyle(selection == i ? tint : Color.mInkTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            selection == i ? Color.mSurface : Color.clear,
                            in: Capsule()
                        )
                        .shadow(color: selection == i ? Color.mInk.opacity(0.08) : .clear, radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Color.mChipFill)
        .clipShape(Capsule())
    }
}

// MARK: - Availability toggle

/// A custom pill switch — sage when on — replacing the native `Toggle`.
struct MAvailabilityToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? Color.mSage : Color.mChipFill)
                .frame(width: 46, height: 27)
                .overlay(
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .padding(2.5)
                        .frame(width: 46, height: 27, alignment: isOn ? .trailing : .leading)
                )
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Price input

/// Inline pill price editor — replaces the old edit-price sheet. Sanitizes to
/// digits only and clamps to 0–999.
struct MPriceInputField: View {
    @Binding var value: Double
    var currencyLabel: String = "ر.س"
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.plexMono(15, weight: .bold))
                .frame(width: 46)
                .focused($focused)
                .onChange(of: text) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    let clamped = min(Int(digits) ?? 0, 999)
                    text = clamped == 0 && digits.isEmpty ? "" : String(clamped)
                    value = Double(clamped)
                }
            Text(currencyLabel)
                .font(.plexArabic(11.5))
                .foregroundStyle(Color.mInkTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .overlay(Capsule().strokeBorder(Color.mLine, lineWidth: 1))
        .environment(\.layoutDirection, .leftToRight)
        .onAppear { text = value == 0 ? "" : "\(Int(value))" }
    }
}

// MARK: - Stat tile (admin dashboard)

struct MStatTile: View {
    let value: String
    let label: String
    var dark: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.plexMono(21, weight: .heavy))
                .foregroundStyle(dark ? .white : Color.mInk)
            Text(label)
                .font(.plexArabic(10.5))
                .foregroundStyle(dark ? Color.mAdminTextSecondary : Color.mInkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(dark ? Color.mAdminSurfaceLight : Color.mChipFill)
        .clipShape(RoundedRectangle(cornerRadius: MTheme.radiusSmall, style: .continuous))
    }
}

// MARK: - Decorative background circles

/// A soft oversized circle bleeding off-screen, used behind splash/welcome/
/// role/auth content at low z-index.
struct MDecorCircle: View {
    let diameter: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
    }
}

// MARK: - Motion

enum MMotion {
    /// Gentle infinite vertical bob for mascot illustrations.
    static func bob(duration: Double = 3.4, delay: Double = 0) -> Animation {
        .easeInOut(duration: duration).delay(delay).repeatForever(autoreverses: true)
    }
    /// Content entry: translateY(14)→0, opacity 0→1.
    static let up = Animation.easeOut(duration: 0.45)
    /// Role-card style scale-in.
    static let scaleIn = Animation.easeOut(duration: 0.45)
}

/// Applies the `mnUp` entry animation: starts offset+faded, animates to rest
/// shortly after appearing.
struct MUpEntry: ViewModifier {
    var delay: Double = 0
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(MMotion.up.delay(delay)) { shown = true }
            }
    }
}

extension View {
    func mUpEntry(delay: Double = 0) -> some View { modifier(MUpEntry(delay: delay)) }
}
