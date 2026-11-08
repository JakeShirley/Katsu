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
- [x] **FND-010** CI build matrix on the `xcode-27` runner image (Xcode 27.2)
  with iOS 27.1+ SDK verification.
- [x] **FND-011** TestFlight upload via semantic-release release workflow.
- [x] **FND-012** Build with the iOS 27 SDK (Xcode 27.2) and raise the minimum
  deployment target to iOS 26.0 in preparation for iPhone Duo.
- **FND-013** iPhone Duo support: adapt layouts to fold states and verify on
  the iPhone Duo simulator (iOS 27.1+).

## Connection & Auth (CON) — v0 scope

- **CON-001** Server URL entry screen with validation against `/api/app/about`.
- **CON-002** OAuth2 password grant login (`POST /api/auth/token`). Also
  covers LDAP-backed servers.
- **CON-003** Persist access token in Keychain, scoped per server profile.
- **CON-004** Fetch and display current user (`/api/users/self`).
- **CON-005** Refresh expired tokens. Katsu currently re-logs in with stored
  credentials; Mealie v3.25.0+ also offers `POST /api/auth/refresh` (the old
  `GET` was removed).
- **CON-006** Sign out clears keychain entry and server profile.
- **CON-007** Multi-server profile switcher.
- **CON-008** Surface auth, offline, TLS, server, and invalid-response errors
  through a single `AppError` type with localized copy.
- **CON-009** Mock backend (`MockMealieAPIClient`) backed by JSON fixtures so
  the app runs entirely offline for previews, tests, and demos.
- **CON-010** Native OIDC sign-in with PKCE via `ASWebAuthenticationSession`
  (`GET /api/auth/oauth/native/config`, `POST /api/auth/oauth/native/token`;
  Mealie v3.23.0+).
- **CON-011** Adapt sign-in to server capabilities and branding from
  `/api/app/about` (`allowPasswordLogin`, `enableOidc`, `oidcProviderName`,
  `brandingName`, `brandingLogoUrl`).
- **CON-012** Prefer `POST /api/auth/refresh` for sliding sessions and only
  fall back to stored-credential re-login when refresh fails.
- [x] **CON-013** Sign in with a long-lived API token for reverse-proxy-auth and
  other setups without password login.
- [x] **CON-014** Detect the server `version` and gate features that need newer
  Mealie releases, with a clear "update your server" message.

## Recipes (REC) — post-v0

- [x] **REC-001** Recipe list (`/api/recipes`) with pagination.
- [x] **REC-002** Recipe detail (ingredients, instructions, nutrition, image).
- [x] **REC-003** Recipe search by name, tag, category, household.
- [x] **REC-004** Import recipe from URL (`POST /api/recipes/create/url`).
- [x] **REC-005** Favorite / rating updates, plus a favorites-only recipe
  list filter that updates immediately and works offline from cached
  favorites.
- [x] **REC-006** Offline cache for recently viewed recipes.
- **REC-007** Structured recipe times (`totalTimeSeconds`, `prepTimeSeconds`,
  `performTimeSeconds`; v3.29.0+) for display, filtering, and sort by total
  time. `cookTime` is removed after v3.30.0; use `performTime`.
- **REC-008** Step timers in making mode from instruction `durationSeconds`
  (v3.30.0+).
- **REC-009** Ingredient substitutions, linked recipe ingredients
  (`referencedRecipe`), and ingredient section titles.
- **REC-010** Metric/imperial conversion using standardized units
  (`standardQuantity`, `standardUnit`).
- **REC-011** Mark as made and recipe timeline
  (`PATCH /api/recipes/{slug}/last-made`, `/api/recipes/timeline/events`).
- **REC-012** Recipe comments (`/api/recipes/{slug}/comments`,
  `/api/comments`).
- **REC-013** AI import from photos, text, or video URLs
  (`POST /api/recipes/create/ai`) and streamed import progress (`/stream`
  variants).
- **REC-014** Share links with QR code (`/api/shared/recipes`).
- **REC-015** "What can I make" suggestions from foods and tools on hand
  (`GET /api/recipes/suggestions`).

## Meal Plans (MP) — post-v0

- **MP-001** This-week meal plan view.
- **MP-002** Add / move / remove planned entries.
- **MP-003** Random meal suggestions
  (`POST /api/households/mealplans/random`).
- **MP-004** Weekly entries without a fixed day (`endDate`,
  `include_week_entries=true`; v3.30.0+).
- **MP-005** Per-entry serving scale (`recipeScale`; v3.29.0+).
- **MP-006** Subscribe to the household meal plan iCal feed from iOS Calendar
  (`/api/households/mealplans/ical`; v3.29.0+).
- **MP-007** Add a date range of planned recipes to a shopping list.

## Shopping Lists (SHOP) — post-v0

- **SHOP-001** Shopping list browser.
- **SHOP-002** Check off items with optimistic UI and conflict reconciliation.
- **SHOP-003** Add free-text and recipe-linked items.
- **SHOP-004** Group items into label sections using the list's
  `labelSettings` order.
- **SHOP-005** Quick add that matches typed text against foods
  (`/api/foods`) and falls back to a note-only item.
- **SHOP-006** Search items within a list.

## Cookbooks (COOK) — post-v0

- **COOK-001** Cookbook list and detail.
- **COOK-002** Add / remove recipes from a cookbook.

## Widgets & App Intents (WID) — post-v0

- **WID-001** Today's meal plan widget
  (`GET /api/households/mealplans/today`).
- **WID-002** Quick "what's for dinner" App Intent.
- **WID-003** Shopping list lock-screen widget.

## Notes

- Mealie feature and API reference, including the supported server baseline
  and client-facing breaking changes: [MEALIE_API.md](MEALIE_API.md). Upstream
  sources are <https://docs.mealie.io/api/redoc/> and each server's live
  `/openapi.json`.
- Self-hosted reality: many Mealie users expose their server over LAN HTTP.
  Katsu v0 keeps ATS strict and ships HTTPS-only; an `NSAllowsArbitraryLoads`
  follow-up is tracked under `CON-007` when multi-server support lands.
