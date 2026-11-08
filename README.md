# Katsu

Katsu is a native SwiftUI companion app for self-hosted [Mealie](https://docs.mealie.io/) recipe servers. The name is taken from the Japanese cutlet — quick, satisfying, and made at home — reflecting the focus on bringing your own recipes to your phone without depending on a SaaS recipe service.

This project is intentionally a companion app, not a recipe authoring backend: a Mealie server remains the source of truth for recipes, meal plans, shopping lists, and household data.

## Current Capabilities (v0)

- Connect to a Mealie server by URL and validate the server is reachable.
- Log in with Mealie's OAuth2 password grant and persist credentials in the Keychain.
- Show the signed-in user, server name, and version on a baseline home screen.
- Sign out and switch servers from settings.
- Run fully offline against a built-in mock server backend for development and previews.

The full backlog and roadmap (recipes, search, meal plans, shopping lists, cookbooks, widgets) lives in [docs/MEALIE_IOS_PROJECT_PLAN.md](docs/MEALIE_IOS_PROJECT_PLAN.md). Katsu's understanding of Mealie's features and REST API is summarized in [docs/MEALIE_API.md](docs/MEALIE_API.md).

## Tech Stack

- Swift, SwiftUI, Swift Concurrency, and `URLSession`.
- UserDefaults-backed server profile storage, Keychain-backed access tokens.
- Xcode project with GitHub Actions CI and semantic-release-based GitHub releases.

## Development

Requirements:

- macOS with Xcode 27.2 or newer (iOS 27.2 SDK). Xcode 27.1 is the minimum for
  iPhone Duo support.
- iOS 27 Simulator runtime (`xcodebuild -downloadPlatform iOS`). The app's
  minimum deployment target is iOS 26.0.
- Node.js 22 for release tooling.

Build locally:

```sh
xcodebuild \
  -project src/Katsu.xcodeproj \
  -scheme Katsu \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Debug launch flags allow targeting either a real Mealie instance or the bundled mock backend. See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the full contributor guide.

## Releases

Releases are managed by semantic-release through GitHub Actions. Conventional Commits determine release notes, tags, and published GitHub releases.

The checked-in app and package versions intentionally remain `0.0.0-development`; release workflows pass the semantic-release version to `xcodebuild` at build time and do not commit version bumps back to the repository.
