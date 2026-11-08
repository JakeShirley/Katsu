# Copilot Instructions

This repository is a native iOS companion app for [Mealie](https://docs.mealie.io/),
the self-hosted recipe manager. The app is named **Katsu**. Follow the project
plan in [docs/MEALIE_IOS_PROJECT_PLAN.md](docs/MEALIE_IOS_PROJECT_PLAN.md),
the developer guide in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md), and the
Mealie feature and API reference in [docs/MEALIE_API.md](docs/MEALIE_API.md).

## Release And Commit Discipline

This project is versioned with semantic-release. Any commits made by an agent
or contributor must use semantic-release-compatible Conventional Commits.

Use these commit types when appropriate:

- `feat`: user-visible feature or capability.
- `fix`: user-visible bug fix.
- `perf`: performance improvement.
- `refactor`: code restructuring without intended behavior change.
- `test`: test-only change.
- `docs`: documentation-only change.
- `build`: build system or dependency change.
- `ci`: CI workflow change.
- `chore`: repository maintenance with no released behavior change.

Include one or more project plan step IDs from
`docs/MEALIE_IOS_PROJECT_PLAN.md` near the start of the commit subject. Use
`type(scope): [PLAN-ID] description` when a scope helps, for example:

```text
feat(connect): [CON-002] log in with mealie oauth2 password grant
fix(connect): [CON-005] refresh access token before expiry
docs(release): document semantic-release workflow
```

If a commit spans multiple planned steps, include each ID in separate brackets,
for example `feat: [CON-001] [CON-002] validate manual server connection`. For
repository-only work that does not map to a planned backlog step, drop the
`[TAG]` and explain why in the commit body.

Mark breaking changes with `!` or a `BREAKING CHANGE:` footer.

Do not manually choose release versions, create release tags, or hand-edit
generated changelog entries during normal feature work. semantic-release owns
those outputs.

Do not commit unless the user explicitly asks for a commit. When the user does
ask for a commit, keep it focused, include the relevant project plan step tag,
and use the Conventional Commit type that matches the release impact.

## Accessibility Baseline (FND-007)

Every new view, control, or modification must meet the following baseline.
Treat this as a hard requirement, not a polish pass.

- Dynamic Type: prefer `Font.title/headline/subheadline/body/caption*` over
  `Font.system(size:)`. If a fixed size is unavoidable, isolate it to a leaf
  view and document why.
- VoiceOver labels:
  - Add `accessibilityLabel` to any `Image`, icon-only `Button`, or chip that
    isn't already self-describing.
  - Use `accessibilityElement(children: .combine)` plus a single
    `accessibilityLabel` for compound rows so VoiceOver speaks one coherent
    phrase per row.
  - Decorative images inside an already-labeled card should be marked
    `.accessibilityHidden(true)`.
- Contrast: use `Color.primary`, `Color.secondary`, system grouped surfaces,
  and the design system tokens in `App/DesignSystem.swift` rather than
  hand-picked colors.
- Reduced motion: gate spring animations, parallax, scale, and slide
  transitions on `@Environment(\.accessibilityReduceMotion)`. Cross-fades and
  state-only changes are fine.
- Hit targets: keep tappable controls at least 44x44 points; if a chip looks
  smaller, wrap it in a `Button` with appropriate padding.

When implementing a new view, include the accessibility hooks in the same
change rather than as a follow-up.

## Localization (FND-008)

Katsu ships English (`en`), Spanish (`es`), German (`de`), and Japanese (`ja`).
Translations live in `src/Katsu/Resources/Localizable.xcstrings` (an Xcode
String Catalog). The development language is English.

When adding or changing user-facing copy:

- Use string literals in SwiftUI initializers that accept
  `LocalizedStringKey`: `Text("Settings")`, `Label("Settings", systemImage:)`,
  `Section("Details")`, etc. These are extracted automatically.
- For non-`Text` consumers (alerts, sheets, dynamic strings), use
  `String(localized: "Cancel")` so xcstringstool can pick them up too.
- Add the new string to `Localizable.xcstrings` with translations for all
  four languages. If a quality translation isn't available, leave the entry
  with `state: needs_review` rather than shipping an obvious machine-grade
  rendering as `translated`.
- Avoid concatenating translated fragments. Use a single localized string
  with positional substitutions instead so translators can reorder.
- Keep brand names ("Katsu", "Mealie"), SF Symbol names, and developer-facing
  diagnostics in English regardless of locale.
- When adding a new locale, also add it to the project's `knownRegions` in
  `src/Katsu.xcodeproj/project.pbxproj`.

## Verifying Swift Changes

Any change that touches a `.swift` file is not "done" until it has been
exercised in the running app. After editing Swift sources you MUST:

1. Build the app for this worktree's iPhone 17 simulator (see
   [Per-Worktree Simulators](#per-worktree-simulators)) and resolve every
   compiler error and warning you introduce. Treat new warnings as failures
   unless the user explicitly says otherwise.
2. Install and launch the freshly built binary on that simulator. Use
   `-debugUseMockServer` for offline iteration; use `-serverURL` against a
   real Mealie instance for end-to-end checks.
3. Drive the affected UI with the `ios-simulator-skill` skill
   (`.agents/skills/ios-simulator-skill/`). Use `screen_mapper.py` to list
   the on-screen elements, then `navigator.py`, `gesture.py`, and
   `keyboard.py` to tap, scroll, and type through the screens your change
   affects.
4. Visually confirm the new behavior — capture a snapshot or screenshot of
   the relevant state and verify it matches the intended outcome (layout,
   copy, accessibility labels, dynamic-type sizing, dark mode if relevant).
   If something looks wrong, iterate until it matches before reporting the
   task complete.

Do not rely solely on "it compiles" or unit tests for Swift work. Skipping
the simulator + `ios-simulator-skill` verification loop is a regression risk
and is not acceptable. If the simulator or the skill is genuinely unavailable
in the current environment, say so explicitly in your final response instead
of silently omitting the verification.

## Driving the iOS Simulator

For visual verification, exploratory checks, and any task that requires
interacting with the running app, use the bundled
[`ios-simulator-skill`](https://github.com/conorluddy/ios-simulator-skill)
skill at `.agents/skills/ios-simulator-skill/`. Load it via the `skill` tool
when you need to drive the simulator. It needs Python 3.12+, `idb` and
`idb-companion` 1.5.1+, and Pillow; check the setup with
`bash .agents/skills/ios-simulator-skill/scripts/sim_health_check.sh`.

Local simulator testing MUST use this worktree's own iPhone 17 simulator.
Pass `--udid "$SIM_UDID"` to every skill script, because the scripts
otherwise pick whichever simulator is booted, and use the `xcodebuild`
destination `id=$SIM_UDID`. Do not target the shared `name=iPhone 17`
simulators. Do not fall back to synthetic taps via `osascript`/`CGEventPost`.
Prefer accessibility targeting (`screen_mapper.py`, then
`navigator.py --find-text "Settings" --tap` or `--find-id`) over screen
coordinates.

`docs/DEVELOPMENT.md` carries the full simulator workflow (mock server vs.
real server, build/install, and the standard inspect/act/verify loop).

### Per-Worktree Simulators

Parallel work streams run in separate git worktrees and MUST NOT share a
simulator, or they will overwrite each other's installs, launch state, and
Keychain. Each worktree owns a dedicated iPhone 17 simulator whose name tracks
the worktree: `Katsu-<worktree directory name>`. Resolve it with:

```sh
SIM_UDID="$(scripts/worktree_simulator.sh)"
```

The script reuses the simulator already named for this worktree. If there is
none, it reclaims a `Katsu-*` simulator whose worktree no longer exists by
erasing it and renaming it with `xcrun simctl rename`, or creates a new one.
It boots the device and prints its UDID. The name is the record of ownership,
so:

- Never boot, install to, or erase another worktree's `Katsu-*` simulator.
- If you add a simulator by hand, name it `Katsu-<worktree directory name>`
  (see `scripts/worktree_simulator.sh --name`) so later runs find it.
- Use the UDID, not the name, in every `xcodebuild`, `simctl`, and
  `ios-simulator-skill` script command. Replace `booted` in `simctl` examples with
  `"$SIM_UDID"`, since several simulators may be booted at once.
