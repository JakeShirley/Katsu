import SwiftUI

/// Shared breakpoints for wide layouts such as iPhone Duo unfolded (inner
/// display ≈ 669pt wide) and iPad.
enum AdaptiveLayout {
    /// Narrowest width at which content can sit as two side-by-side "pages".
    static let twoPageMinimumWidth: CGFloat = 600

    /// Horizontal content margin applied to both edges of each page in a
    /// two-page layout, so the gutter between pages is twice this value.
    static let twoPageMargin: CGFloat = DesignSystem.Spacing.lg

    /// Narrowest width at which a list/detail split keeps both columns on
    /// screen. Below it (iPhone Duo or iPad mini in portrait) the system
    /// would overlay the sidebar on an empty detail, so split views collapse
    /// into a single stack instead.
    static let splitViewMinimumWidth: CGFloat = 800

    /// Comfortable maximum line/card width for single-column content on iPad.
    static let readableContentMaxWidth: CGFloat = 700

    /// Comfortable maximum width for focused onboarding and sign-in forms on iPad.
    static let formMaxWidth: CGFloat = 560

    static func isTwoPage(width: CGFloat) -> Bool {
        width >= twoPageMinimumWidth
    }
}

/// An active fold (a `.division` reserved region) on a foldable display such
/// as iPhone Duo. The system only reports the fold as active while the hinge
/// is partially open; when the device lies flat the fold is ignorable and
/// content may span it.
struct DeviceFold: Equatable {
    enum Orientation {
        /// The fold runs top to bottom (book posture).
        case vertical
        /// The fold runs side to side (tabletop posture).
        case horizontal
    }

    /// The region content should avoid, including the system's recommended
    /// margins on either side of the fold, in global coordinates.
    var frame: CGRect

    var orientation: Orientation {
        frame.height > frame.width ? .vertical : .horizontal
    }

    /// The x position of a vertical fold's center, in global coordinates.
    var verticalFoldX: CGFloat? {
        orientation == .vertical ? frame.midX : nil
    }
}

extension EnvironmentValues {
    /// The device's active fold, or `nil` when there is none (no hinge, the
    /// hinge is flat, or iOS earlier than 27.1). Published from the app root
    /// by `tracksDeviceFold()`.
    @Entry var deviceFold: DeviceFold?
}

extension View {
    /// Reads the device's `.division` reserved region (iOS 27.1+) and
    /// publishes it as `deviceFold` to this view's descendants. Attach it to a
    /// view that fills the window, such as the window root.
    func tracksDeviceFold() -> some View {
        modifier(DeviceFoldTracker())
    }

    /// Reports whether this view is wide enough for a two-page layout.
    func onTwoPageWidthChange(_ action: @escaping (Bool) -> Void) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            AdaptiveLayout.isTwoPage(width: proxy.size.width)
        } action: { isTwoPage in
            action(isTwoPage)
        }
    }

    /// Constrains single-column scroll content to a comfortable reading width
    /// on wide displays (such as iPad) while leaving compact widths full-bleed.
    func readableContentWidth(_ maxWidth: CGFloat = AdaptiveLayout.readableContentMaxWidth) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }

    /// Constrains an inset-grouped `List` or `Form` to a readable content width
    /// on wide displays while preserving full-bleed backgrounds, edge scroll
    /// indicators, and native system margins on compact widths.
    func readableListContentWidth(_ maxWidth: CGFloat = AdaptiveLayout.readableContentMaxWidth) -> some View {
        modifier(ReadableListContentWidthModifier(maxWidth: maxWidth))
    }
}

private struct ReadableListContentWidthModifier: ViewModifier {
    let maxWidth: CGFloat
    @State private var margins: EdgeInsets?

    func body(content: Content) -> some View {
        content
            .contentMargins(.leading, margins?.leading, for: .scrollContent)
            .contentMargins(.trailing, margins?.trailing, for: .scrollContent)
            .onGeometryChange(for: EdgeInsets?.self) { proxy in
                let defaultSideMargin = DesignSystem.Spacing.lg
                let availableWidth = proxy.size.width
                guard availableWidth > maxWidth + (defaultSideMargin * 2) else {
                    return nil
                }
                let sideInset = (availableWidth - maxWidth) / 2
                // `contentMargins` on `List` measures from the scroll view's
                // bounds rather than adding to safe-area insets (such as the
                // iPad landscape tab sidebar), so include them explicitly.
                return EdgeInsets(
                    top: 0,
                    leading: sideInset + proxy.safeAreaInsets.leading,
                    bottom: 0,
                    trailing: sideInset + proxy.safeAreaInsets.trailing
                )
            } action: { newMargins in
                margins = newMargins
            }
    }
}

private struct DeviceFoldTracker: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settler = FoldSettler()

    func body(content: Content) -> some View {
        content
            .environment(\.deviceFold, settler.fold)
            .background {
                if #available(iOS 27.1, *) {
                    Color.clear
                        .onGeometryChange(for: CGRect?.self) { proxy in
                            guard let region = proxy.reservedRegions(kind: .division).first(where: \.isActive) else {
                                return nil
                            }
                            let origin = proxy.frame(in: .global).origin
                            return region.frame.offsetBy(dx: origin.x, dy: origin.y)
                        } action: { frame in
                            settler.update(frame.map(DeviceFold.init(frame:)))
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

/// Debounces fold activation so fold-aware layouts only engage once the hinge
/// has come to rest partially open. Folding the device shut sweeps through the
/// partially open range, and snapping layouts on the way would be jarring.
/// Deactivation and changes to an already active fold apply immediately.
@MainActor
@Observable
private final class FoldSettler {
    static let settleDelay: Duration = .milliseconds(400)

    private(set) var fold: DeviceFold?
    @ObservationIgnored var animation: Animation?
    @ObservationIgnored private var settleTask: Task<Void, Never>?

    func update(_ newFold: DeviceFold?) {
        settleTask?.cancel()
        settleTask = nil

        guard let newFold else {
            apply(nil)
            return
        }

        if fold != nil {
            apply(newFold)
            return
        }

        settleTask = Task { [weak self] in
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            self?.apply(newFold)
        }
    }

    private func apply(_ newFold: DeviceFold?) {
        guard fold != newFold else { return }
        withAnimation(animation) {
            fold = newFold
        }
    }
}
