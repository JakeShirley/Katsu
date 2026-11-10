import PhotosUI
import SwiftUI

/// Picks or scans recipe photos, reads them on-device, and hands an editable
/// draft to `RecipeDraftReviewView`.
struct PhotoRecipeImportView: View {
    struct Page: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    struct ReviewInput: Identifiable, Hashable {
        let id = UUID()
        let draft: RecipeDraft
        let recognizedText: String
        let notice: String?
        let photos: [Data]

        static func == (lhs: ReviewInput, rhs: ReviewInput) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private enum Stage: Equatable {
        case idle
        case loadingPhotos
        case readingText
        case structuring
    }

    static let maximumPages = 6

    @Environment(\.dismiss) private var dismiss
    @State private var pages: [Page] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showScanner = false
    @State private var stage: Stage = .idle
    @State private var errorMessage: String?
    @State private var reviewInput: ReviewInput?
    @State private var processingTask: Task<Void, Never>?

    let onImported: () async -> Void

    private var modelAvailability: RecipeDraftGenerator.Availability {
        RecipeDraftGenerator.availability
    }

    private var isBusy: Bool {
        stage != .idle
    }

    var body: some View {
        Form {
            Section {
                Text("Take or choose photos of a recipe card or cookbook page. Katsu reads them on this device, then lets you review the recipe before importing it into Mealie.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Section {
                modelStatusRow
            }

            Section {
                if DocumentScannerView.isSupported {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan Pages", systemImage: "doc.viewfinder")
                    }
                    .frame(minHeight: DesignSystem.HitTarget.minimum)
                    .disabled(isBusy || pages.count >= Self.maximumPages)
                }

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: max(1, Self.maximumPages - pages.count),
                    matching: .images
                ) {
                    Label("Choose Photos", systemImage: "photo.on.rectangle")
                }
                .frame(minHeight: DesignSystem.HitTarget.minimum)
                .disabled(isBusy || pages.count >= Self.maximumPages)
            } header: {
                Text("Photos")
            } footer: {
                Text("Add up to \(Self.maximumPages) pages, in reading order.")
            }

            if !pages.isEmpty {
                Section("Pages") {
                    pageStrip
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.destructive)
                }
            }

            Section {
                Button(action: readRecipe) {
                    if isBusy {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ProgressView()
                            Text(stageTitle)
                        }
                    } else {
                        Text("Read Recipe")
                    }
                }
                .disabled(isBusy || pages.isEmpty)
                .frame(minHeight: DesignSystem.HitTarget.minimum)
            }
        }
        .navigationTitle("Import from Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    processingTask?.cancel()
                    dismiss()
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            loadPickedPhotos(items)
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { images in
                showScanner = false
                appendPages(images)
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .navigationDestination(item: $reviewInput) { input in
            RecipeDraftReviewView(
                draft: input.draft,
                recognizedText: input.recognizedText,
                notice: input.notice,
                photos: input.photos
            ) {
                await onImported()
                dismiss()
            }
        }
        .onDisappear {
            processingTask?.cancel()
        }
    }

    @ViewBuilder
    private var modelStatusRow: some View {
        switch modelAvailability {
        case .available:
            Label {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("On-device Apple Intelligence")
                        .font(.subheadline.weight(.semibold))
                    Text("Your photos never leave this device until you import the reviewed recipe.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "apple.intelligence")
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        case .unavailable(let reason):
            Label {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                    Text("Basic text recognition")
                        .font(.subheadline.weight(.semibold))
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Katsu will sort the text into ingredients and steps as best it can. Review it carefully before importing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(DesignSystem.Colors.warning)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var pageStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageThumbnail(page, number: index + 1)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .scrollIndicators(.hidden)
    }

    private func pageThumbnail(_ page: Page, number: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: page.image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                .accessibilityLabel(Text("Page \(number)"))

            Button {
                pages.removeAll { $0.id == page.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel(Text("Remove page \(number)"))
        }
    }

    private var stageTitle: LocalizedStringKey {
        switch stage {
        case .idle, .loadingPhotos:
            "Loading photos…"
        case .readingText:
            "Reading text…"
        case .structuring:
            "Organizing recipe…"
        }
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        stage = .loadingPhotos
        errorMessage = nil
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            if images.count < items.count {
                errorMessage = String(localized: "Some photos couldn't be loaded.")
            }
            appendPages(images)
            pickerItems = []
            stage = .idle
        }
    }

    private func appendPages(_ images: [UIImage]) {
        let room = Self.maximumPages - pages.count
        guard room > 0 else { return }
        pages.append(contentsOf: images.prefix(room).map { Page(image: Self.normalized($0)) })
    }

    private func readRecipe() {
        guard !pages.isEmpty, !isBusy else { return }
        errorMessage = nil
        let images = pages.compactMap(\.image.cgImage)
        let photos = pages.compactMap { $0.image.jpegData(compressionQuality: 0.85) }

        processingTask = Task {
            defer { stage = .idle }
            do {
                stage = .readingText
                let text = try await RecipeTextRecognizer.recognizeText(in: images)
                guard !text.isEmpty else {
                    errorMessage = String(localized: "Katsu couldn't find any text in these photos. Try a sharper, well-lit photo.")
                    return
                }

                var draft: RecipeDraft
                var notice: String?
                let standardizes = MeasurementNormalizer.applies(to: text)
                switch modelAvailability {
                case .available:
                    stage = .structuring
                    do {
                        draft = try await RecipeDraftGenerator.generate(text: text, images: images)
                    } catch is CancellationError {
                        return
                    } catch {
                        draft = .heuristic(from: text, standardizingMeasurements: standardizes)
                        notice = RecipeDraftGenerator.userFacingMessage(for: error)
                    }
                case .unavailable(let reason):
                    draft = .heuristic(from: text, standardizingMeasurements: standardizes)
                    notice = reason
                }

                try Task.checkCancellation()
                if standardizes {
                    draft.standardizeMeasurements()
                }
                reviewInput = ReviewInput(
                    draft: draft,
                    recognizedText: text,
                    notice: notice,
                    photos: photos
                )
            } catch is CancellationError {
                return
            } catch {
                errorMessage = String(localized: "Katsu couldn't read these photos. Try again with clearer pages.")
            }
        }
    }

    /// Redraws the photo upright and caps its size so Vision and the
    /// language model get a correctly oriented, reasonably sized image.
    private static func normalized(_ image: UIImage, maximumDimension: CGFloat = 2048) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maximumDimension ? maximumDimension / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
