import AudioToolbox
import SwiftUI
import UIKit
import UserNotifications

struct RecipeMakingModeView: View {
    let detail: MealieRecipeDetail
    let ingredientScaleFactor: Double
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var selectedPage = 0
    @State private var timerMinutes = 5
    @State private var timerEndDate: Date?
    @State private var now = Date.now
    @State private var didPlayTimerCompletionAlert = false

    private static let timerNotificationID = "katsu.makingMode.timer"

    private var pages: [RecipeMakingPage] {
        var pages = [RecipeMakingPage.ingredients(detail.recipeIngredient)]
        pages.append(contentsOf: (detail.recipeInstructions ?? []).enumerated().map { index, instruction in
            RecipeMakingPage.step(index: index + 1, instruction: instruction)
        })
        return pages
    }

    /// Seconds left on the running timer, derived from its end date so the
    /// countdown stays accurate while the app is in the background.
    private var timerRemainingSeconds: Int? {
        timerEndDate.map { max(0, Int($0.timeIntervalSince(now).rounded(.up))) }
    }

    var body: some View {
        NavigationStack {
            content
                .background {
                    DesignSystem.Colors.background
                        .ignoresSafeArea()
                }
                .navigationTitle(detail.displayName)
                .navigationSubtitle("Making Mode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .close) {
                            dismiss()
                        }
                        .accessibilityLabel("Close making mode")
                    }
                }
        }
        .accessibilityAction(.escape) {
            dismiss()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            tickTimer()
        }
        .onAppear {
            // Keep the screen awake while cooking.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            cancelTimerNotification()
        }
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 27.1, *), horizontalSizeClass == .regular, verticalSizeClass == .regular {
            splitLayout
        } else {
            VStack(spacing: DesignSystem.Spacing.lg) {
                timerPanel
                progressStrip
                pager
                navigationControls
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }

    /// Regular-size layout (iPad, unfolded iPhone Duo). The system arranges
    /// the step card and its controls side by side or stacked to suit the
    /// display, and keeps both clear of an active fold: in book posture the
    /// card and controls sit on opposite pages, and in tabletop posture the
    /// card faces the cook on the upper half with the controls below.
    @available(iOS 27.1, *)
    private var splitLayout: some View {
        ArrangementView {
            VStack(spacing: DesignSystem.Spacing.md) {
                progressStrip
                pager
            }
            .padding(.vertical, DesignSystem.Spacing.md)
        } secondary: {
            ViewThatFits(in: .vertical) {
                controlsStack
                    .frame(maxHeight: .infinity)
                ScrollView {
                    controlsStack
                }
            }
        }
        .arrangementViewStyle(.split)
    }

    private var controlsStack: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            timerPanel
            navigationControls
                .controlSize(.large)
        }
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    private var timerPanel: some View {
        RecipeMakingTimerPanel(
            timerMinutes: $timerMinutes,
            remainingSeconds: timerRemainingSeconds,
            onStart: startTimer,
            onCancel: cancelTimer
        )
    }

    private var pager: some View {
        TabView(selection: $selectedPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                RecipeMakingCard(page: page, totalSteps: max(pages.count - 1, 0))
                    .environment(\.recipeIngredientScaleFactor, ingredientScaleFactor)
                    .tag(index)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .accessibilityElement(children: .contain)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(reduceMotion ? nil : DesignSystem.Motion.standard, value: selectedPage)
    }

    private var progressStrip: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= selectedPage ? DesignSystem.Colors.accent : DesignSystem.Colors.separator.opacity(0.45))
                    .frame(height: 4)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Making mode page \(selectedPage + 1) of \(pages.count)"))
    }

    private var navigationControls: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                movePage(by: -1)
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
            }
            .buttonStyle(.bordered)
            .disabled(selectedPage == 0)
            .accessibilityLabel("Previous making mode card")

            Button {
                if selectedPage == pages.count - 1 {
                    dismiss()
                } else {
                    movePage(by: 1)
                }
            } label: {
                Label(selectedPage == pages.count - 1 ? "Finish" : "Next", systemImage: selectedPage == pages.count - 1 ? "checkmark.circle.fill" : "chevron.right")
                    .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(selectedPage == pages.count - 1 ? "Finish making mode" : "Next making mode card")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func movePage(by offset: Int) {
        let nextPage = min(max(selectedPage + offset, 0), pages.count - 1)
        if reduceMotion {
            selectedPage = nextPage
        } else {
            withAnimation(DesignSystem.Motion.standard) {
                selectedPage = nextPage
            }
        }
    }

    private func startTimer() {
        let duration = TimeInterval(timerMinutes * 60)
        now = .now
        timerEndDate = now.addingTimeInterval(duration)
        didPlayTimerCompletionAlert = false
        scheduleTimerNotification(after: duration)
    }

    private func cancelTimer() {
        timerEndDate = nil
        didPlayTimerCompletionAlert = false
        cancelTimerNotification()
    }

    private func tickTimer() {
        guard timerEndDate != nil else { return }
        now = .now
        if timerRemainingSeconds == 0 {
            playTimerCompletionAlertIfNeeded()
        }
    }

    /// Alerts the cook when the timer ends while Katsu is in the background
    /// or the device is locked. Permission is requested the first time a
    /// timer starts, when the reason is clear.
    private func scheduleTimerNotification(after duration: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Timer finished")
        content.body = detail.displayName
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.timerNotificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        )

        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            try? await center.add(request)
        }
    }

    private func cancelTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.timerNotificationID])
    }

    private func playTimerCompletionAlertIfNeeded() {
        guard !didPlayTimerCompletionAlert else { return }
        didPlayTimerCompletionAlert = true
        playTimerCompletionAlert()
    }

    private func playTimerCompletionAlert() {
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

private struct RecipeMakingTimerPanel: View {
    @Binding var timerMinutes: Int
    let remainingSeconds: Int?
    let onStart: () -> Void
    let onCancel: () -> Void

    private var isTimerRunning: Bool {
        remainingSeconds.map { $0 > 0 } ?? false
    }

    private var formattedRemainingTime: String {
        let remainingSeconds = remainingSeconds ?? timerMinutes * 60
        return Self.durationFormatter.string(from: TimeInterval(remainingSeconds)) ?? "0:00"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Label("Timer", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: DesignSystem.Spacing.md)

                Text(formattedRemainingTime)
                    .font(.title.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(isTimerRunning ? DesignSystem.Colors.accentDeep : .secondary)
                    .accessibilityLabel(timerStatusAccessibilityLabel)
            }

            Stepper(value: $timerMinutes, in: 1...240) {
                Text(timerDurationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .disabled(isTimerRunning)

            HStack(spacing: DesignSystem.Spacing.md) {
                Button {
                    onStart()
                } label: {
                    Label(
                        remainingSeconds == 0 ? "Restart" : "Start",
                        systemImage: remainingSeconds == 0 ? "arrow.clockwise" : "play.fill"
                    )
                        .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isTimerRunning)
                .accessibilityLabel(remainingSeconds == 0 ? "Restart timer" : "Start timer")

                Button {
                    onCancel()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
                }
                .buttonStyle(.bordered)
                .disabled(remainingSeconds == nil)
                .accessibilityLabel("Cancel timer")
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.separator.opacity(0.55), lineWidth: 1)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .accessibilityElement(children: .contain)
    }

    private var timerStatusAccessibilityLabel: String {
        if remainingSeconds == 0 {
            String(localized: "Timer finished")
        } else if isTimerRunning {
            String(localized: "Timer running, \(formattedRemainingTime) remaining")
        } else {
            String(localized: "Timer set for \(timerDurationText)")
        }
    }

    private var timerDurationText: String {
        if timerMinutes == 1 {
            String(localized: "1 minute")
        } else {
            String(localized: "\(timerMinutes) minutes")
        }
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}

private enum RecipeMakingPage {
    case ingredients([MealieRecipeIngredient])
    case step(index: Int, instruction: MealieRecipeInstruction)
}

private struct RecipeMakingCard: View {
    let page: RecipeMakingPage
    let totalSteps: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                switch page {
                case .ingredients(let ingredients):
                    ingredientsContent(ingredients)
                case .step(let index, let instruction):
                    stepContent(index: index, instruction: instruction)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.separator.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }

    private func ingredientsContent(_ ingredients: [MealieRecipeIngredient]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            cardEyebrow("Get Set")
            Text("Ingredients")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            if ingredients.isEmpty {
                ContentUnavailableView("No ingredients listed", systemImage: "list.bullet.clipboard")
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ForEach(ingredients) { ingredient in
                        RecipeMakingIngredientRow(ingredient: ingredient)
                    }
                }
            }
        }
    }

    private func stepContent(index: Int, instruction: MealieRecipeInstruction) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            cardEyebrow(String(localized: "Step \(index) of \(totalSteps)"))
            Text(String(localized: "Step \(index)"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(instruction.displayText)
                .font(.title3)
                .lineSpacing(6)
                .foregroundStyle(.primary)
                .accessibilityLabel(String(localized: "Step \(index), \(instruction.displayText)"))
        }
    }

    private func cardEyebrow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(DesignSystem.Colors.accentDeep)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.accentSoft, in: Capsule())
    }
}

private struct RecipeMakingIngredientRow: View {
    @Environment(\.recipeIngredientScaleFactor) private var scaleFactor
    let ingredient: MealieRecipeIngredient

    private var display: RecipeIngredientDisplay {
        RecipeIngredientDisplay(ingredient: ingredient, scaleFactor: scaleFactor)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(display.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let measurement = display.measurement {
                    Text(measurement)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.accentDeep)
                }

                if let note = display.note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.accessibilityLabel)
    }
}

private struct RecipeIngredientScaleFactorKey: EnvironmentKey {
    static let defaultValue = 1.0
}

private extension EnvironmentValues {
    var recipeIngredientScaleFactor: Double {
        get { self[RecipeIngredientScaleFactorKey.self] }
        set { self[RecipeIngredientScaleFactorKey.self] = newValue }
    }
}
