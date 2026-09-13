import SwiftUI

/// The brand mascot — a coffee-cup character — faithfully translated from the
/// SVG `<symbol>` artwork in the Claude Design handoff (`mn-mascot`,
/// `mn-mascot-calm`, `mn-mascot-apron`), not redrawn from scratch. Drawn on a
/// Canvas at the artwork's native 120×142 viewBox and scaled to whatever
/// frame the caller requests.
enum MascotVariant {
    /// Waving, steaming, holding an "A01" card — splash / welcome.
    case `default`
    /// Neutral, holding the card, no steam/wave — customer role card, empty states.
    case calm
    /// Wearing a sage apron, no card — merchant role card, merchant auth, admin empty state.
    case apron
}

struct MenyuMascot: View {
    var variant: MascotVariant = .default
    var animated: Bool = true
    var bobDuration: Double = 3.4
    var bobDelay: Double = 0

    @State private var bob = false

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .offset(y: animated && bob ? -9 : 0)
        .rotationEffect(.degrees(animated ? (bob ? 1.5 : -1.5) : 0))
        .onAppear {
            guard animated else { return }
            withAnimation(MMotion.bob(duration: bobDuration, delay: bobDelay)) { bob = true }
        }
        .aspectRatio(120.0 / 142.0, contentMode: .fit)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width / 120, size.height / 142)
        let dx = (size.width - 120 * scale) / 2
        let dy = (size.height - 142 * scale) / 2
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: dx + x * scale, y: dy + y * scale) }
        func len(_ v: CGFloat) -> CGFloat { v * scale }

        let cupInk = Color(hex: 0x201E1D)
        let cupCream = Color(hex: 0xFDF7EE)
        let lidBase: Color
        let lidDark: Color
        let bodyStroke: Color
        let badgeFill: Color
        switch variant {
        case .default, .calm:
            lidBase = .mAccent; lidDark = .mAccent600; bodyStroke = .mAccent300; badgeFill = .mAccent200
        case .apron:
            lidBase = .mSage; lidDark = .mSage600; bodyStroke = .mSage300; badgeFill = .mSage200
        }

        // Steam + waving arm (default variant only).
        if variant == .default {
            var steamL = Path()
            steamL.move(to: pt(47, 16))
            steamL.addQuadCurve(to: pt(47, 3), control: pt(54, 10))
            context.stroke(steamL, with: .color(.mSage500), lineWidth: len(4.5))

            var steamR = Path()
            steamR.move(to: pt(64, 18))
            steamR.addQuadCurve(to: pt(64, 3), control: pt(72, 11))
            context.stroke(steamR, with: .color(.mSage400), style: StrokeStyle(lineWidth: len(4.5), lineCap: .round))
        }

        // Left arm (handle), always present.
        var armL = Path()
        armL.move(to: pt(20, 74))
        armL.addQuadCurve(to: pt(10, 94), control: pt(7, 79))
        context.stroke(armL, with: .color(.mAccent700), style: StrokeStyle(lineWidth: len(7), lineCap: .round))

        // Right arm — waving on the default variant, resting handle otherwise.
        var armR = Path()
        armR.move(to: pt(96, 70))
        armR.addQuadCurve(to: pt(112, 51), control: pt(111, 65))
        context.stroke(armR, with: .color(.mAccent700), style: StrokeStyle(lineWidth: len(7), lineCap: .round))
        if variant == .default {
            context.fill(Path(ellipseIn: CGRect(x: pt(112, 48).x - len(6), y: pt(112, 48).y - len(6), width: len(12), height: len(12))), with: .color(.mAccent700))
        }

        // Lid (two stacked ellipses).
        context.fill(Path(ellipseIn: CGRect(x: pt(20, 24).x, y: pt(20, 24).y, width: len(80), height: len(20))), with: .color(lidBase))
        context.fill(Path(ellipseIn: CGRect(x: pt(33, 19.5).x, y: pt(33, 19.5).y, width: len(54), height: len(15))), with: .color(lidDark))

        // Cup body — tapered trapezoid, rounded bottom corners (approximated).
        var body = Path()
        body.move(to: pt(24, 44))
        body.addLine(to: pt(96, 44))
        body.addLine(to: pt(87, 114))
        body.addQuadCurve(to: pt(73, 126), control: pt(87, 126))
        body.addLine(to: pt(47, 126))
        body.addQuadCurve(to: pt(33, 114), control: pt(33, 126))
        body.closeSubpath()
        context.fill(body, with: .color(cupCream))
        context.stroke(body, with: .color(bodyStroke), lineWidth: len(2.5))

        // Cheeks — default variant only, matching the source artwork.
        if variant == .default {
            for cx: CGFloat in [41, 79] {
                let r: CGFloat = 5.5
                context.fill(
                    Path(ellipseIn: CGRect(x: pt(cx - r, 72 - r).x, y: pt(cx - r, 72 - r).y, width: len(r * 2), height: len(r * 2))),
                    with: .color(bodyStroke.opacity(0.75))
                )
            }
        }

        // Eyes.
        for cx: CGFloat in [50, 71] {
            let rx: CGFloat = 4.6, ry: CGFloat = 5.8
            context.fill(
                Path(ellipseIn: CGRect(x: pt(cx - rx, 62 - ry).x, y: pt(cx - rx, 62 - ry).y, width: len(rx * 2), height: len(ry * 2))),
                with: .color(cupInk)
            )
        }

        // Smile.
        var smile = Path()
        smile.move(to: pt(52, 74))
        smile.addQuadCurve(to: pt(69, 74), control: pt(60.5, 81.5))
        context.stroke(smile, with: .color(cupInk), style: StrokeStyle(lineWidth: len(3.2), lineCap: .round))

        // Badge — code card (default/calm) or apron straps (apron).
        let badgeRect = CGRect(x: pt(29, 88).x, y: pt(29, 88).y, width: len(62), height: len(24))
        context.fill(Path(roundedRect: badgeRect, cornerRadius: len(7)), with: .color(badgeFill))

        switch variant {
        case .default, .calm:
            context.draw(
                Text("A01").font(.plexMono(len(14), weight: .heavy)).foregroundStyle(Color.mAccent800),
                at: pt(60, 100)
            )
        case .apron:
            var strapA = Path()
            strapA.move(to: pt(38, 96)); strapA.addLine(to: pt(82, 96))
            var strapB = Path()
            strapB.move(to: pt(38, 104)); strapB.addLine(to: pt(68, 104))
            context.stroke(strapA, with: .color(.mSage700), style: StrokeStyle(lineWidth: len(3), lineCap: .round))
            context.stroke(strapB, with: .color(.mSage700), style: StrokeStyle(lineWidth: len(3), lineCap: .round))
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        MenyuMascot(variant: .default).frame(width: 90, height: 106)
        MenyuMascot(variant: .calm).frame(width: 90, height: 106)
        MenyuMascot(variant: .apron).frame(width: 90, height: 106)
    }
    .padding()
}
