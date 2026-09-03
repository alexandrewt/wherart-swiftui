import SwiftUI

struct SplashView: View {
    let onComplete: () -> Void

    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var logoOffsetY: CGFloat = 0
    @State private var backgroundOpacity: Double = 1.0

    var body: some View {
        ZStack {
            Color(red: 0.15, green: 0.39, blue: 0.92)
                .ignoresSafeArea()
                .opacity(backgroundOpacity)

            Image("Vector")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .offset(y: logoOffsetY)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            // No shared-namespace geometry match to LoginView — the logo just
            // slides up and fades out in place, and LoginView's title block
            // fades/slides in on its own timer. Simple, local, no cross-view
            // coordinate-space dependency to get wrong.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeIn(duration: 0.35)) {
                    logoOffsetY = -180
                    logoOpacity = 0.0
                }
                withAnimation(.easeOut(duration: 0.35)) {
                    backgroundOpacity = 0.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
                onComplete()
            }
        }
    }
}

#Preview {
    SplashView(onComplete: {})
}
