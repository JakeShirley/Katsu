# Katsu Project Plan

Katsu is a native iOS companion app for self-hosted Mealie servers. This document
tracks the high-level backlog. Use the IDs below in commit messages, e.g.
`feat(connect): [CON-002] log in with mealie oauth2 password grant`.

The v0 (baseline) milestone is **server connection + login**. Everything else is
later work; do not block v0 on it.

## Foundation (FND)

- [x] **FND-001** Scaffold the Katsu Xcode project, scheme, and bundle identifier
  (`org.odinseye.katsu`).
- [x] **FND-002** Document architecture (App / Domain / Networking / Storage /
  Features) and contributor workflow.
- [x] **FND-003** Wire `AppEnvironment` for dependency injection (API client,
  credential store, preference store, profile store).
- [x] **FND-004** Persist active server profile and preferences in UserDefaults.
- [x] **FND-005** Design system (`DesignSystem.swift`) with Katsu palette tokens.
- [x] **FND-006** App icon and accent color. Icon is generated from
  [Icon Kitchen](https://icon.kitchen/i/H4sIAAAAAAAAA0WPzQrCMBCE32W9elBLS-nVgy_gTUQSdxuCMVvSxB9K393diphDwsxOPmYneJhQaIRugt7tOXCCDlb9cmAN9u81pkJqxZNc8INJWT-NJA8g9aaELEN_5ShGNjfiki_oo48OZiUd3wPJyCWDnqKGrTv8hKIyD0uRzVKBcFdXEtqqoraxFSrHRBcEU23rL5ReuSQxpln0nbEE3eYkOUzsUSvxKPeTLJznDyfWIxjwAAAA);
  see `docs/ICON.md` for the replacement workflow.
- [x] **FND-007** Accessibility baseline: Dynamic Type, VoiceOver labels, contrast,
  reduced motion, 44pt hit targets. See `AGENTS.md` for the rules.
- [x] **FND-008** Localization for `en`, `es`, `de`, `ja` via
  `Localizable.xcstrings`. Mark non-English entries `needs_review` until a
  translator passes.
- [x] **FND-009** Diagnostics bundle generator that redacts server host, username,
  token, and password.
- [x] **FND-010** CI build matrix on `macos-26` with iOS SDK verification.
- [x] **FND-011** TestFlight upload via semantic-release release workflow.

## Connection & Auth (CON) — v0 scope

- **CON-001** Server URL entry screen with validation against `/api/app/about`.
- **CON-002** OAuth2 password grant login (`POST /api/auth/token`).
- **CON-003** Persist access token in Keychain, scoped per server profile.
- **CON-004** Fetch and display current user (`/api/users/self`).
- **CON-005** Refresh expired tokens (`POST /api/auth/refresh`).
- **CON-006** Sign out clears keychain entry and server profile.
- **CON-007** Multi-server profile switcher.
- **CON-008** Surface auth, offline, TLS, server, and invalid-response errors
  through a single `AppError` type with localized copy.
- **CON-009** Mock backend (`MockMealieAPIClient`) backed by JSON fixtures so
  the app runs entirely offline for previews, tests, and demos.

## Recipes (REC) — post-v0

- [x] **REC-001** Recipe list (`/api/recipes`) with pagination.
- [x] **REC-002** Recipe detail (ingredients, instructions, nutrition, image).
- [x] **REC-003** Recipe search by name, tag, category, household.
- **REC-004** Import recipe from URL (`POST /api/recipes/create-url`).
- **REC-005** Favorite / rating updates.
- **REC-006** Offline cache for recently viewed recipes.

## Meal Plans (MP) — post-v0

- **MP-001** This-week meal plan view.
- **MP-002** Add / move / remove planned entries.
- **MP-003** Random meal suggestions.

## Shopping Lists (SHOP) — post-v0

- **SHOP-001** Shopping list browser.
- **SHOP-002** Check off items with optimistic UI and conflict reconciliation.
- **SHOP-003** Add free-text and recipe-linked items.

## Cookbooks (COOK) — post-v0

- **COOK-001** Cookbook list and detail.
- **COOK-002** Add / remove recipes from a cookbook.

## Widgets & App Intents (WID) — post-v0

- **WID-001** Today's meal plan widget.
- **WID-002** Quick "what's for dinner" App Intent.
- **WID-003** Shopping list lock-screen widget.

## Notes

- Mealie API reference: <https://docs.mealie.io/api/redoc/> and the live
  `/openapi.json` on each server.
- Self-hosted reality: many Mealie users expose their server over LAN HTTP.
  Katsu v0 keeps ATS strict and ships HTTPS-only; an `NSAllowsArbitraryLoads`
  follow-up is tracked under `CON-007` when multi-server support lands.
