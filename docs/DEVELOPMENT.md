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
  previews, snapshot tests, and offline iteration.

## Debug App Configuration

The app supports debug configuration through launch arguments and environment
variables:

```sh
xcrun simctl launch --terminate-running-process booted org.odinseye.katsu \
  --args -serverURL https://food.tespia.org
```

Supported debug inputs:

- `-serverURL <url>` / `KATSU_SERVER_URL=<url>`: prefill server URL.
- `-debugUseMockServer` / `KATSU_USE_MOCK_SERVER=1`: route all API calls
  through `MockMealieAPIClient`.
- `-debugAuthToken <token>` / `KATSU_DEBUG_AUTH_TOKEN=<token>`: skip the login
  screen by injecting a token into the keychain at launch.
- `-debugShowSettings`: open settings on launch for visual checks.
- `-debugShowChangelog`: open the changelog screen on launch for visual
  checks.

The active server profile and app preferences are persisted with `UserDefaults`.
Access tokens live in the Keychain.

## Verifying Swift Changes

Any change that touches a `.swift` file is not "done" until it has been
exercised in the running app. After editing Swift sources you MUST:

1. Build the app for the iPhone 17 iOS Simulator and resolve every compiler
   error and warning you introduce.
2. Install and launch the freshly built binary on an iPhone 17 simulator. Use
   `-debugUseMockServer` for offline iteration; use `-serverURL` against your
   real Mealie instance for end-to-end checks.
3. Drive the affected UI with the `agent-device` skill
   (`.opencode/skills/agent-device/`). Use `agent-device snapshot -i` to find
   accessibility refs, then click/type/scroll to reach the screens your
   change affects.
4. Visually confirm the new behavior — capture a snapshot or screenshot and
   verify it matches the intended outcome.

Do not rely solely on "it compiles" for Swift work. Local simulator testing
must always use an iPhone 17 simulator, including `agent-device` setup/open
commands and any `xcodebuild` simulator destination.

## Wide And Foldable Layouts

Wide layouts target the unfolded iPhone Duo (inner display ≈ 669×951pt) and
also apply on iPad and landscape iPhones. Breakpoints live in
`src/Katsu/Features/Shared/AdaptiveLayout.swift` and are based on measured
geometry, not size classes or the iOS 27.1 hinge API:

- Two-page (width ≥ 600pt): the recipe feed becomes a 2-column card grid and
  recipe detail becomes a cookbook spread (overview and ingredients on the
  left, instructions and nutrition on the right).
- Tabletop (landscape, height ≥ 500pt): Making Mode puts the step card above
  the horizontal hinge and the timer and Back/Next controls below it.

The Duo simulator cannot be unfolded headlessly, so use an iPad mini
simulator as a wide stand-in, and still regression-check iPhone 17.

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
