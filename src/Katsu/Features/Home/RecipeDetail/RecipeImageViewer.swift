import SwiftUI

struct RecipeImageViewer: View {
    let imageURL: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .tint(.white)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .offset(x: offset.width + dragTranslation.width, y: offset.height + dragTranslation.height)
                        .scaleEffect(scale)
                        .gesture(imageGestures)
                        .onTapGesture(count: 2) {
                            withAnimation(DesignSystem.Motion.standard) {
                                if scale > 1 {
                                    resetImageTransform()
                                } else {
                                    scale = 2
                                    committedScale = 2
                                }
                            }
                        }
                        .accessibilityLabel(title)
                case .failure:
                    ContentUnavailableView("Could not load image", systemImage: "photo")
                        .foregroundStyle(.white)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .padding(DesignSystem.Spacing.lg)
            .accessibilityLabel("Close image viewer")
        }
    }

    private var imageGestures: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = max(1, min(committedScale * value.magnification, 5))
            }
            .onEnded { _ in
                committedScale = scale
                if scale == 1 {
                    resetImageTransform()
                }
            }
            .simultaneously(with: DragGesture()
                .onChanged { value in
                    dragTranslation = value.translation
                }
                .onEnded { value in
                    if scale <= 1, value.translation.height > 120, abs(value.translation.width) < 80 {
                        dismiss()
                    } else {
                        committedOffset.width += value.translation.width
                        committedOffset.height += value.translation.height
                        offset = committedOffset
                    }
                    dragTranslation = .zero
                }
            )
    }

    private func resetImageTransform() {
        scale = 1
        committedScale = 1
        offset = .zero
        committedOffset = .zero
        dragTranslation = .zero
    }
}
