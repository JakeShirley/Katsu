import SwiftUI

/// Shared breakpoints for wide layouts such as iPhone Duo unfolded (inner
/// display ≈ 669pt wide) and iPad.
enum AdaptiveLayout {
    /// Narrowest width at which content can sit as two side-by-side "pages",
    /// one on each side of the iPhone Duo hinge.
    static let twoPageMinimumWidth: CGFloat = 600

    /// Horizontal content margin applied to both edges of each page in a
    /// two-page layout, so the gutter at the hinge is twice this value.
    static let twoPageMargin: CGFloat = DesignSystem.Spacing.lg

    /// Shortest landscape height that can split into upper and lower halves.
    /// Ordinary phones in landscape (≈440pt or less) stay below this.
    static let tabletopMinimumHeight: CGFloat = 500

    static func isTwoPage(width: CGFloat) -> Bool {
        width >= twoPageMinimumWidth
    }

    /// Landscape with enough height to split into upper and lower halves along
    /// a horizontal hinge (iPhone Duo held like a laptop).
    static func isTabletop(size: CGSize) -> Bool {
        size.width > size.height && size.height >= tabletopMinimumHeight
    }

    /// Book posture: the hinge is partially open and the screen is held in
    /// landscape, so the fold runs top to bottom through the screen's center
    /// (iPhone Duo half closed like an open book).
    static func isBookPosture(isHingePartiallyOpen: Bool, screenSize: CGSize) -> Bool {
        isHingePartiallyOpen && screenSize.width > screenSize.height
    }
}

extension EnvironmentValues {
    /// The x position of the fold, in global coordinates, while the device is
    /// in book posture; `nil` otherwise. Two-pane layouts split exactly here so
    /// each half of the screen shows one pane. Published from the app root by
    /// `tracksDeviceHinge()`.
    @Entry var bookFoldX: CGFloat?
}

extension View {
    /// Observes the device hinge (iOS 27.1+) and the screen it spans, and
    /// publishes `bookFoldX` to this view's descendants. Attach it to a view
    /// that fills the screen, such as the window root or a full-screen cover.
    func tracksDeviceHinge() -> some View {
        modifier(DeviceHingeTracker())
    }

    /// Reports whether this view is wide enough for a two-page layout.
    func onTwoPageWidthChange(_ action: @escaping (Bool) -> Void) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            AdaptiveLayout.isTwoPage(width: proxy.size.width)
        } action: { isTwoPage in
            action(isTwoPage)
        }
    }
}

private struct DeviceHingeTracker: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settler = HingeSettler()
    @State private var screenFrame: CGRect = .zero

    private var bookFoldX: CGFloat? {
        guard AdaptiveLayout.isBookPosture(
            isHingePartiallyOpen: settler.isSettledPartiallyOpen,
            screenSize: screenFrame.size
        ) else { return nil }
        return screenFrame.midX
    }

    func body(content: Content) -> some View {
        content
            .environment(\.bookFoldX, bookFoldX)
            .background {
                // Some insets (e.g. the unfolded Duo's trailing status and tab
                // column) can't be ignored, so add back whatever safe area the
                // view still reports to recover the whole screen.
                Color.clear
                    .ignoresSafeArea()
                    .onGeometryChange(for: CGRect.self) { proxy in
                        let frame = proxy.frame(in: .global)
                        let insets = proxy.safeAreaInsets
                        return CGRect(
                            x: frame.minX - insets.leading,
                            y: frame.minY - insets.top,
                            width: frame.width + insets.leading + insets.trailing,
                            height: frame.height + insets.top + insets.bottom
                        )
                    } action: { frame in
                        screenFrame = frame
                    }
            }
            .background {
                if #available(iOS 27.1, *) {
                    HingeObserverView { isPartiallyOpen, angle in
                        settler.update(isPartiallyOpen: isPartiallyOpen, angle: angle)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .onAppear {
                settler.animation = reduceMotion ? nil : DesignSystem.Motion.emphasized
            }
            .onChange(of: reduceMotion) { _, reduceMotion in
                settler.animation = reduceMotion ? nil : DesignSystem.Motion.emphasized
            }
    }
}

/// Debounces hinge updates so book posture only engages once the hinge has
/// come to rest partially open. Folding the device shut sweeps through the
/// partially open range, and snapping layouts on the way would be jarring.
@MainActor
@Observable
private final class HingeSettler {
    /// How long the hinge must hold still before book posture engages.
    static let settleDelay: Duration = .milliseconds(400)
    /// Angle change, in radians (2°), that counts as the hinge still moving.
    static let movementTolerance: CGFloat = .pi / 90

    private(set) var isSettledPartiallyOpen = false
    @ObservationIgnored var animation: Animation?
    @ObservationIgnored private var restingAngle: CGFloat?
    @ObservationIgnored private var settleTask: Task<Void, Never>?

    func update(isPartiallyOpen: Bool, angle: CGFloat) {
        guard isPartiallyOpen else {
            settleTask?.cancel()
            settleTask = nil
            restingAngle = nil
            setSettled(false)
            return
        }

        if let restingAngle, abs(angle - restingAngle) <= Self.movementTolerance {
            return
        }

        restingAngle = angle
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.setSettled(true)
        }
    }

    private func setSettled(_ isSettled: Bool) {
        guard isSettledPartiallyOpen != isSettled else { return }
        withAnimation(animation) {
            isSettledPartiallyOpen = isSettled
        }
    }
}

/// Reports hinge status and angle through UIKit, which, unlike SwiftUI's
/// `onHingeChange`, exposes the angle needed to tell when the hinge is moving.
@available(iOS 27.1, *)
private struct HingeObserverView: UIViewRepresentable {
    let onUpdate: @MainActor (_ isPartiallyOpen: Bool, _ angle: CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        let coordinator = context.coordinator
        coordinator.onUpdate = onUpdate
        view.addInteraction(UIHingeInteraction { _, update in
            guard let hinge = update.hinge else {
                coordinator.onUpdate?(false, 0)
                return
            }
            coordinator.onUpdate?(hinge.status == .partiallyOpen, hinge.angle)
        })
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onUpdate = onUpdate
    }

    @MainActor
    final class Coordinator {
        var onUpdate: (@MainActor (_ isPartiallyOpen: Bool, _ angle: CGFloat) -> Void)?
    }
}
