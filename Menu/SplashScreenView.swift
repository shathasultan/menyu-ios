import SwiftUI

/// Shown for ~3s on every cold launch. Midnight-gradient background ("ليل
/// وزعفران" identity), the layered-card logo mark settling into place, then
/// "Menu" typed out in English beneath it.
struct SplashScreenView: View {
    private let fullText = "Menu"

    @State private var cardsAppeared = false
    @State private var visibleCharacterCount = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.mAccent, Color.mAccentDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                logoMark
                    .frame(width: 132, height: 132)

                Text(String(fullText.prefix(visibleCharacterCount)))
                    .font(.plexMono(30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(height: 36)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .task {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
                cardsAppeared = true
            }
            try? await Task.sleep(for: .seconds(0.45))
            for i in 1...fullText.count {
                visibleCharacterCount = i
                try? await Task.sleep(for: .seconds(0.09))
            }
        }
    }

    private var logoMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.32))
                .frame(width: 68, height: 42)
                .rotationEffect(.degrees(-11))
                .offset(x: 14, y: 10)

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.mBackground)
                .frame(width: 72, height: 44)
                .rotationEffect(.degrees(cardsAppeared ? 6 : -6))
                .offset(x: -14, y: -8)
        }
        .scaleEffect(cardsAppeared ? 1 : 0.6)
        .opacity(cardsAppeared ? 1 : 0)
    }
}

#Preview {
    SplashScreenView()
}
