import SwiftUI

/// Brand moment on cold start — white background, bobbing mascot, wordmark.
/// Auto-advances after ~2000ms; tapping anywhere skips immediately.
struct SplashScreenView: View {
    var onFinished: () -> Void

    @State private var advanced = false

    var body: some View {
        ZStack {
            Color.mBackground.ignoresSafeArea()

            MDecorCircle(diameter: 260, color: .mAccent100, corner: .topTrailing, offset: CGSize(width: 160, height: -160))

            MDecorCircle(diameter: 200, color: .mSage100, corner: .bottomLeading, offset: CGSize(width: -160, height: 140))

            VStack(spacing: 26) {
                MenyuMascot(variant: .default, bobDuration: 3.0)
                    .frame(width: 132, height: 156)

                Text("menu.")
                    .font(.plexMono(26, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(Color.mInk)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task {
            try? await Task.sleep(for: .milliseconds(2000))
            finish()
        }
    }

    private func finish() {
        guard !advanced else { return }
        advanced = true
        onFinished()
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
