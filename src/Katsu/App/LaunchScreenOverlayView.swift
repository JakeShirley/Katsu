import SwiftUI

/// Seamless animated handoff from iOS's static `UILaunchScreen`.
///
/// The initial frame matches `UILaunchScreen` (`LaunchBackground` + centered 120×120pt
/// `LaunchLogo` badge) so there is no visual jump when SwiftUI takes over. When
/// Reduce Motion is off, the Katsu takeout-box lid pops open with a spring before
/// the overlay fades away to reveal the app. When Reduce Motion is on, the overlay
/// cross-fades out without spring, rotation, or scale motion.
struct LaunchScreenOverlayView: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var lidOpen = false
    @State private var isFadingOut = false

    private static let badgeSize: CGFloat = 120
    private static let badgeCornerRadius: CGFloat = 27

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            katsuLogoBadge
                .scaleEffect(logoScale)
        }
        .compositingGroup()
        .opacity(isFadingOut ? 0 : 1)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            await runAnimation()
        }
    }

    private var logoScale: CGFloat {
        guard !reduceMotion else { return 1 }
        if isFadingOut { return 1.12 }
        if lidOpen { return 1.05 }
        return 1
    }

    private var katsuLogoBadge: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 254.0 / 255.0, green: 210.0 / 255.0, blue: 83.0 / 255.0),
                    Color(red: 232.0 / 255.0, green: 107.0 / 255.0, blue: 61.0 / 255.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            KatsuBoxBaseShape()
                .fill(.white)

            KatsuBoxLidShape()
                .fill(.white)
                .offset(y: lidOpen && !reduceMotion ? -4.5 : 0)
                .rotationEffect(
                    .degrees(lidOpen && !reduceMotion ? -11 : 0),
                    anchor: UnitPoint(x: 0.28, y: 0.44)
                )
        }
        .frame(width: Self.badgeSize, height: Self.badgeSize)
        .clipShape(RoundedRectangle(cornerRadius: Self.badgeCornerRadius, style: .circular))
    }

    @MainActor
    private func runAnimation() async {
        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                isFadingOut = true
            }
            try? await Task.sleep(for: .milliseconds(270))
            guard !Task.isCancelled else { return }
            onFinished()
            return
        }

        // Brief hold so frame 0 aligns cleanly with iOS's static launch screen.
        try? await Task.sleep(for: .milliseconds(90))
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 0.36, dampingFraction: 0.56)) {
            lidOpen = true
        }

        try? await Task.sleep(for: .milliseconds(360))
        guard !Task.isCancelled else { return }

        withAnimation(.easeIn(duration: 0.28)) {
            isFadingOut = true
        }

        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        onFinished()
    }
}

/// Bottom trapezoid of the Katsu takeout box, normalized to the 1024×1024 app icon grid.
private struct KatsuBoxBaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let scale: CGFloat = 1024

        var path = Path()
        path.move(to: CGPoint(x: 312.5 / scale * w, y: 499.0 / scale * h))
        path.addLine(to: CGPoint(x: 711.5 / scale * w, y: 499.0 / scale * h))
        path.addLine(to: CGPoint(x: 692.5 / scale * w, y: 751.0 / scale * h))
        path.addLine(to: CGPoint(x: 331.5 / scale * w, y: 751.0 / scale * h))
        path.closeSubpath()
        return path
    }
}

/// Top lid and angled side flaps of the Katsu takeout box, normalized to the 1024×1024 app icon grid.
private struct KatsuBoxLidShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let scale: CGFloat = 1024

        let points: [(CGFloat, CGFloat)] = [
            (422, 244),
            (602, 244),
            (722, 364),
            (722, 382),
            (769, 335),
            (809, 375),
            (732, 452),
            (292, 452),
            (215, 375),
            (255, 335),
            (302, 382),
            (302, 364)
        ]

        var path = Path()
        if let first = points.first {
            path.move(to: CGPoint(x: first.0 / scale * w, y: first.1 / scale * h))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.0 / scale * w, y: point.1 / scale * h))
            }
            path.closeSubpath()
        }
        return path
    }
}
