import SwiftUI

/// A reusable swipe-to-delete row that mirrors the destructive interaction
/// used by the Settings → Servers list. The host owns `isRevealed` so it can
/// coordinate "only one row revealed at a time" across a list.
///
/// The row layers a fixed-width destructive button beneath `content`. A
/// horizontal drag offsets `content` to expose the button; tapping the
/// revealed button calls `onRemove` directly (no confirmation dialog).
///
/// Animations are gated on `accessibilityReduceMotion`, and a custom
/// VoiceOver "Delete" action is exposed via `accessibilityAction` on the
/// caller's row content (this view doesn't add one itself).
struct SwipeToRemoveRow<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isRevealed: Bool
    let onRemove: () -> Void
    let contentBackground: Color?
    @ViewBuilder let content: Content

    @State private var dragTranslation: CGFloat = 0

    private let actionWidth: CGFloat = 112

    init(
        isRevealed: Binding<Bool>,
        onRemove: @escaping () -> Void,
        contentBackground: Color? = DesignSystem.Colors.surface,
        @ViewBuilder content: () -> Content
    ) {
        self._isRevealed = isRevealed
        self.onRemove = onRemove
        self.contentBackground = contentBackground
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: onRemove) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 42)
                        .background(DesignSystem.Colors.destructive, in: Capsule())
                        .scaleEffect(actionScale)

                    Text("Delete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .opacity(actionLabelOpacity)
                }
                .frame(width: actionWidth)
                .frame(minHeight: DesignSystem.HitTarget.minimum + DesignSystem.Spacing.xl)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
            .accessibilityHidden(!isRevealed)
            .opacity(actionOpacity)

            content
                .frame(maxWidth: .infinity)
                .background(contentBackground)
                .offset(x: rowOffset)
                .highPriorityGesture(removeRevealGesture)
                .animation(reduceMotion ? nil : DesignSystem.Motion.standard, value: isRevealed)
                .animation(reduceMotion ? nil : DesignSystem.Motion.standard, value: dragTranslation)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var rowOffset: CGFloat {
        let baseOffset = isRevealed ? -actionWidth : 0
        return min(0, max(-actionWidth, baseOffset + dragTranslation))
    }

    private var actionProgress: CGFloat {
        min(1, max(0, abs(rowOffset) / actionWidth))
    }

    private var actionScale: CGFloat {
        0.72 + (actionProgress * 0.28)
    }

    private var actionOpacity: CGFloat {
        min(1, max(0, (actionProgress - 0.15) / 0.85))
    }

    private var actionLabelOpacity: CGFloat {
        min(1, max(0, (actionProgress - 0.35) / 0.65))
    }

    private var removeRevealGesture: some Gesture {
        DragGesture(minimumDistance: DesignSystem.Spacing.sm)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let baseOffset = isRevealed ? -actionWidth : 0
                dragTranslation = min(0, max(-actionWidth, baseOffset + value.translation.width)) - baseOffset
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    dragTranslation = 0
                    return
                }
                let baseOffset = isRevealed ? -actionWidth : 0
                let projectedOffset = baseOffset + value.translation.width + (value.predictedEndTranslation.width - value.translation.width) * 0.25
                isRevealed = projectedOffset < -actionWidth / 2
                dragTranslation = 0
            }
    }
}
