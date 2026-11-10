# Development Guide

This project is versioned and released with semantic-release.

## Versioning And Releases

Use semantic-release as the source of truth for release versions, release notes,
and Git tags. Do not manually choose release versions or hand-edit generated
changelog entries as part of normal feature work.

Expected release model:

- Commits use Conventional Commits.
- semantic-release analyzes commits to decide the next version.
- CI publishes release notes and tags when changes land on the release branch.
- Release automation uses Node.js 24 and semantic-release 25. Checkout and
  Node setup actions use their Node.js 24-based v7 releases, and the provisioning
  profile action uses v7 with explicit ES module metadata.
- iOS marketing versions are derived from the semantic-release version during
  release automation.
- iOS build numbers can remain CI-generated monotonic build identifiers.
- GitHub Actions iOS jobs run on the `xcode-27` image, select Xcode 27.2 via
  `DEVELOPER_DIR`, and fail if the iOS SDK is older than 27.1 (the first SDK
  with iPhone Duo support).
- The app's minimum deployment target is iOS 26.0.
- Checked-in Xcode and package versions stay at `0.0.0-development`; release
  builds pass the semantic-release version to `xcodebuild` without committing
  that bump back to the repository.

The release workflow intentionally does not use `@semantic-release/git`,
`@semantic-release/changelog`, or any other plugin that commits generated
version or changelog changes back to the repository.

### TestFlight Uploads

When semantic-release creates a new release on `main`, the GitHub Actions
release workflow uses Apple Actions to import the Apple Distribution
certificate, download the App Store provisioning profile, and upload the
exported IPA to TestFlight. The local release script archives and exports the
signed IPA so the marketing version can come from the semantic-release
version.

Required GitHub Actions `AppStore` environment secrets:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_PRIVATE_KEY` — full `.p8` contents.
- `IOS_DISTRIBUTION_CERTIFICATE_BASE64` — base64-encoded `.p12`.
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` — `.p12` password.

The App Store Connect record for `org.odinseye.katsu` and an active App Store
provisioning profile that includes the Apple Distribution certificate must
already exist. See the project history for the previous BirdNET-Go iteration
of this guide if you need a step-by-step certificate walkthrough.

## Commit Message Format

All feature, bug fix, maintenance, documentation, test, and CI commits should
use semantic-release-compatible Conventional Commits:

```text
<type>(optional-scope): [PLAN-ID] <description>

optional body

optional footer
```

Include one or more project plan step IDs from
[docs/MEALIE_IOS_PROJECT_PLAN.md](MEALIE_IOS_PROJECT_PLAN.md) near the start of
the subject. If a commit spans multiple planned steps, include each ID in
separate brackets. For repository-only work that does not map to a planned
backlog step, drop the `[TAG]` and explain why in the commit body.

Examples:

```text
feat: [FND-001] scaffold Katsu Xcode project
feat(connect): [CON-002] log in with mealie oauth2 password grant
fix(connect): [CON-005] refresh access token before expiry
docs: [FND-002] document katsu architecture
```

Common types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `ci`,
`chore`. Breaking changes use `!` after the type or a `BREAKING CHANGE:` footer.

## Agent And Contributor Expectations

- Do not make a Git commit unless explicitly asked.
- When asked to commit, use a Conventional Commit message that semantic-release
  can analyze and include the relevant project plan step tag.
- Prefer small commits with one release meaning each.
- Do not manually edit generated release notes, tags, or version bumps unless
  the release automation itself is being fixed.
- If a change is user-visible, choose `feat`, `fix`, or `perf` instead of
  hiding it under `chore`.

## Server Backends

Katsu can be pointed at either a real Mealie server or a built-in mock backend.

- **Real server**: pass `-serverURL https://your-mealie.example.com` (or set
  `KATSU_SERVER_URL`) at simulator launch. You will need to enter your
  username and password in the simulator UI; never commit credentials.
- **Mock backend**: pass `-debugUseMockServer` (or set
  `KATSU_USE_MOCK_SERVER=1`). The app uses `MockMealieAPIClient`, an
  in-memory implementation backed by JSON fixtures bundled in
  `src/Katsu/Resources/Fixtures/`. No network is touched. Use this for
  previews, snapshot tests, and offline iteration. Sign in with `chef` /
  `katsu`, or choose **API Token** and paste `mock-api-token`.

## Debug App Configuration

The app supports debug configuration through launch arguments and environment
variables:

```sh
xcrun simctl launch --terminate-running-process "$SIM_UDID" org.odinseye.katsu \
  --args -serverURL https://food.tespia.org
```

`$SIM_UDID` is this worktree's simulator; see
[Per-Worktree Simulators](#per-worktree-simulators).

Supported debug inputs:

- `-serverURL <url>` / `KATSU_SERVER_URL=<url>`: prefill server URL.
- `-debugUseMockServer` / `KATSU_USE_MOCK_SERVER=1`: route all API calls
  through `MockMealieAPIClient`.
- `-debugAuthToken <token>` / `KATSU_DEBUG_AUTH_TOKEN=<token>`: skip the login
  screen by injecting a token into the keychain at launch.
- `-debugMockServerVersion <version>` / `KATSU_MOCK_SERVER_VERSION=<version>`:
  version the mock backend reports from `/api/app/about` (default `v3.30.0`).
  Use an older value such as `v1.12.0` to check server-version gates.
- `-debugShowSettings`: open settings on launch for visual checks.
- `-debugShowChangelog`: open the changelog screen on launch for visual
  checks.

The active server profile and app preferences are persisted with `UserDefaults`.
Access tokens live in the Keychain.

## Verifying Swift Changes

Any change that touches a `.swift` file is not "done" until it has been
exercised in the running app. After editing Swift sources you MUST:

1. Build the app for this worktree's iPhone 17 simulator and resolve every
   compiler error and warning you introduce.
2. Install and launch the freshly built binary on that simulator. Use
   `-debugUseMockServer` for offline iteration; use `-serverURL` against your
   real Mealie instance for end-to-end checks.
3. Drive the affected UI with the `ios-simulator-skill` skill
   (`.agents/skills/ios-simulator-skill/`). Use `screen_mapper.py` to list
   the on-screen elements, then `navigator.py`, `gesture.py`, and
   `keyboard.py` to tap, scroll, and type through the screens your change
   affects.
4. Visually confirm the new behavior — capture a snapshot or screenshot and
   verify it matches the intended outcome.

Do not rely solely on "it compiles" for Swift work. Local simulator testing
must always use this worktree's own iPhone 17 simulator, including every
`ios-simulator-skill` script (`--udid "$SIM_UDID"`) and any `xcodebuild`
simulator destination.

The skill needs Python 3.12+, `idb` and `idb-companion` 1.5.1+, and Pillow
(for visual diffs). On a new machine:

```sh
brew trust --formula facebook/fb/idb-cli
brew trust --formula facebook/fb/idb-companion
brew install facebook/fb/idb pillow
bash .agents/skills/ios-simulator-skill/scripts/sim_health_check.sh
```

## Per-Worktree Simulators

Agents and contributors often run several work streams at once, each in its
own git worktree. Sharing one "iPhone 17" simulator between them causes
installs, launch arguments, and Keychain state to clobber each other, so every
worktree gets a dedicated iPhone 17 simulator. The simulator's name records
which worktree owns it: `Katsu-<worktree directory name>`.

Resolve (and boot) this worktree's simulator with:

```sh
SIM_UDID="$(scripts/worktree_simulator.sh)"
```

The script:

1. Reuses the available simulator named `Katsu-<worktree directory name>`.
2. Otherwise reclaims a `Katsu-*` iPhone 17 simulator whose worktree no longer
   appears in `git worktree list`: it erases the device and renames it to this
   worktree with `xcrun simctl rename`.
3. Otherwise creates a new iPhone 17 simulator with that name.

Use the UDID everywhere so commands never land on another stream's device:

```sh
xcodebuild -project src/Katsu.xcodeproj -scheme Katsu \
  -destination "id=$SIM_UDID" -derivedDataPath build/DerivedData build
xcrun simctl install "$SIM_UDID" \
  build/DerivedData/Build/Products/Debug-iphonesimulator/Katsu.app
xcrun simctl launch --terminate-running-process "$SIM_UDID" org.odinseye.katsu \
  --args -debugUseMockServer
SIM_SKILL=.agents/skills/ios-simulator-skill/scripts
python3 "$SIM_SKILL/screen_mapper.py" --udid "$SIM_UDID"
python3 "$SIM_SKILL/navigator.py" --udid "$SIM_UDID" --find-text "Settings" --tap
```

Rules:

- Never boot, install to, or erase a `Katsu-*` simulator named after another
  worktree. Only simulators whose worktree is gone may be reclaimed.
- Avoid `booted` in `simctl` commands; several simulators may be booted.
- If you create or rename a simulator by hand, use the name printed by
  `scripts/worktree_simulator.sh --name`.
- To clean up after removing worktrees, delete leftover devices with
  `xcrun simctl delete <udid>`, or leave them for the script to reclaim.

## Wide And Foldable Layouts

Wide layouts target the unfolded iPhone Duo (inner display ≈ 669×951pt) and
also apply on iPad and landscape iPhones. Breakpoints live in
`src/Katsu/Features/Shared/AdaptiveLayout.swift` and are based on measured
geometry, not size classes:

- Two-page (width ≥ 600pt): the recipe feed becomes a 2-column card grid and
  recipe detail becomes a cookbook spread (overview and ingredients on the
  left, instructions and nutrition on the right). Recipe detail is one
  `ScrollView` of `RecipeDetailCard`s whose two page columns switch between
  `VStackLayout` and `HStackLayout` through `AnyLayout`, so when the width
  crosses the breakpoint (for example, the split view's sidebar sliding in
  or out) the cards animate to their new places instead of being rebuilt.
  Both pages therefore scroll together. Size the pages from layout size, not
  the global frame, which can be stale after rotation.
- List/detail: `RecipesView` is a `NavigationSplitView` (recipe list in the
  sidebar, detail beside it) when it is at least
  `AdaptiveLayout.splitViewMinimumWidth` (800pt) wide. Narrower containers,
  including the unfolded Duo and iPad mini in portrait, override the size
  class to compact so the split collapses into a stack instead of overlaying
  the sidebar on an empty detail; rotating keeps the open recipe. When the
  device is flat open, the system clamps the sidebar to about a third of the
  display, so sidebar rows must reflow rather than truncate (`RecipeRow`
  uses `ViewThatFits` for its metadata).
- Fold: the app root's `.tracksDeviceFold()` reads SwiftUI's iOS 27.1
  `reservedRegions(kind: .division)` and publishes the hinge as the
  `\.deviceFold` environment value (a `DeviceFold` with a global frame and
  orientation; `nil` otherwise). The system only reports a division region
  while the hinge is partially open; a flat-open display is one continuous
  surface by Apple's design, so layouts must look right with no fold at all.
  A fold engages only after it has stayed put for 400ms, so folding the
  device shut never flashes a split, and it clears immediately. Changes
  animate with `DesignSystem.Motion.emphasized` unless Reduce Motion is on;
  views that restructure for the fold should also attach
  `.animation(_:value: deviceFold)`, because the root transaction doesn't
  reach presented content such as full-screen covers.
- Two-pane views split exactly at `deviceFold?.verticalFoldX` when present
  (and evenly otherwise) so each half of the display shows one pane: the
  feed grid's gutter equals the fold, recipe detail's spread pages meet at
  the fold, and the split view's sidebar width matches the left page. The
  fold is measured on the full screen, including the trailing status/tab
  column that `ignoresSafeArea` cannot expand into.
- Making Mode: on regular×regular (iOS 27.1+) it uses `ArrangementView` with
  `.arrangementViewStyle(.split)`, letting the system place the step card
  and the timer/Back/Next controls on either side of a vertical (book) or
  horizontal (tabletop) fold. Compact layouts keep a single column. Making
  Mode keeps the screen awake, and its timer counts down to an end date and
  schedules a local notification so it survives backgrounding.

Colors come from asset catalog colorsets (`AccentColor`, `AccentDeep`,
`AccentSoft`) with light, dark, and Increase Contrast variants; the light
accent is darkened so tinted text and white-on-accent labels meet WCAG AA.
Use the `DesignSystem.Palette`/`Colors` tokens rather than literal colors.

`simctl` cannot unfold the Duo simulator (`screenConfig power` leaves the
inner display black). Unfold it with the skill's experimental `duo.py`, which
requires an explicit Duo UDID:

```sh
SIM_SKILL=.agents/skills/ios-simulator-skill/scripts
python3 "$SIM_SKILL/duo.py" --udid "$DUO_UDID" --pose open
python3 "$SIM_SKILL/duo.py" --udid "$DUO_UDID" --state --json  # note display_id
python3 "$SIM_SKILL/app_state_capture.py" --udid "$DUO_UDID" --display 3 \
  --output duo-state
```

For book posture, run `--pose open` first and then `--pose partial`.
Going straight from closed to `partial` keeps the app on the cover display.
Alternate between `open` and `partial` to check that layouts switch live.

Use the `display_id` that `--state` reports rather than assuming 3; you can
also capture the inner display with
`xcrun simctl io "$DUO_UDID" screenshot --display=3`. The
unfolded Duo runs landscape with the status bar and tab bar in a column on
the trailing edge, so wide layouts must account for that safe-area inset.
An iPad mini simulator remains a quick wide stand-in; still regression-check
iPhone 17.

## App Structure

The iOS app keeps foundation code in separate source areas so feature work can
grow without mixing concerns:

- `src/Katsu/App`: SwiftUI app entry point, root view, app configuration, and
  dependency environment wiring.
- `src/Katsu/Domain`: shared app models and DTOs (`MealieServerInfo`,
  `MealieUser`, `MealieAuthToken`, `ServerProfile`, `AppError`).
- `src/Katsu/Networking`: Mealie API client protocols and URLSession +
  in-memory mock implementations.
- `src/Katsu/Storage`: storage protocols, UserDefaults-backed profile and
  preference persistence, Keychain-backed token storage.
- `src/Katsu/Features`: user-facing SwiftUI feature modules. v0 ships
  `Onboarding`, `Home`, and `Settings`.
- `src/Katsu/Resources`: assets, Info.plist, `Localizable.xcstrings`, and
  bundled JSON fixtures used by the mock client. The app icon is generated
  via Icon Kitchen — see [`docs/ICON.md`](ICON.md) for the source URL and
  replacement workflow.
