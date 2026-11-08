# Mealie Feature And API Reference

This is Katsu's working summary of what Mealie can do and which REST endpoints
back each capability. It is the source of truth for API assumptions in
`src/Katsu/Networking` and for scoping backlog items in
[MEALIE_IOS_PROJECT_PLAN.md](MEALIE_IOS_PROJECT_PLAN.md).

- **Baseline:** Mealie **v3.30.0** (released 2026-10-31), cross-checked against
  the `nightly` OpenAPI document served by <https://demo.mealie.io> on
  2026-11-08.
- **Authoritative sources:** each server's live `/openapi.json` (interactive
  docs at `/docs`), the hosted reference at <https://docs.mealie.io/api/redoc/>,
  and the [release notes](https://github.com/mealie-recipes/mealie/releases).
- **Refreshing this doc:** download `/openapi.json` from the demo or a current
  server, diff the path list against the tables below, and read every release
  note since the baseline for "Breaking changes" and "for app developers"
  callouts. Update the baseline line above when done.

## API Conventions

- All routes live under `/api`. Authenticate with
  `Authorization: Bearer <token>`. Session tokens and long-lived API tokens
  are both accepted as bearer tokens.
- JSON bodies and responses are camelCase, except OAuth-style auth responses
  (`access_token`, `token_type`) and pagination envelopes (`per_page`,
  `total_pages`).
- Paginated collections accept `page`, `perPage`, `orderBy`,
  `orderDirection`, `orderByNullPosition`, `queryFilter`, and
  `paginationSeed`, and return `{ page, per_page, total, total_pages, items,
  next, previous }`. `perPage=-1` returns everything.
- `queryFilter` is Mealie's filter DSL (for example
  `lastMade <= "$NOW-30d"` or `rating >= 4`); `$NOW` placeholders arrived in
  v3.11.0. See
  [API usage](https://docs.mealie.io/documentation/getting-started/api-usage/).
- Data is scoped by **group** (shared catalog: foods, units, labels, tags,
  categories, tools, recipes) and **household** (meal plans, shopping lists,
  cookbooks, webhooks, recipe actions). Builds after v3.30.0 reject writes that
  cross group or household boundaries.
- Most routes accept an `accept-language` header that localizes server-side
  messages and generated content.
- Recipe images: `/api/media/recipes/{recipeId}/images/{original.webp |
  min-original.webp | tiny-original.webp}`. Assets and timeline images live
  beside them.

## Server Discovery And Capabilities

| Endpoint | Auth | Notes |
| --- | --- | --- |
| `GET /api/app/about` | none | `version`, `production`, `demoStatus`, `allowSignup`, `allowPasswordLogin`, `enableOidc`, `oidcRedirect`, `oidcProviderName`, `enableReverseProxyAuth`, `tokenTime` (hours), `defaultGroupSlug`, `defaultHouseholdSlug`, `allowedIframeHosts`, `brandingName`, `brandingLogoUrl`. Katsu validates servers with this (CON-001). |
| `GET /api/app/about/startup-info` | none | `isFirstLogin`, `isDemo`. |
| `GET /api/app/about/theme` | none | Light/dark palette the admin configured. |
| `GET /api/app/about/branding-logo` | none | Custom instance logo (v3.29.0+). |
| `GET /api/admin/about[/statistics\|/check]` | admin | Server config health and statistics. |

Use `version` to gate features: `nightly`/`develop` builds report a non-semver
string, so treat unparseable versions as "latest". Katsu parses it into
`MealieServerVersion` and declares minimums on `MealieFeature`
(`src/Katsu/Domain/MealieServerVersion.swift`); views check
`AppEnvironment.supports(_:)` and show an "update your server" message when the
active server is too old (CON-014). The version is re-read from
`/api/app/about` whenever the active profile loads so gates follow server
upgrades. Current gates: households routes (meal plans, shopping lists)
v2.0.0, `snack`/`drink`/`dessert` meal types v3.7.0, and `includeCategories`
on URL import v3.10.0.

## Authentication

| Flow | Endpoints | Since | Katsu |
| --- | --- | --- | --- |
| Password grant | `POST /api/auth/token` (form: `username`, `password`, `remember_me`) | — | CON-002 |
| Token refresh | `POST /api/auth/refresh` with a valid bearer session token | v3.25.0 (`GET` removed) | Not used yet; Katsu re-logs in with stored credentials (CON-005). |
| Logout | `POST /api/auth/logout` | v3.25.0 | — |
| Native OIDC (PKCE) | `GET /api/auth/oauth/native/config` → `{ authorization_endpoint, client_id, scope }`; `POST /api/auth/oauth/native/token` with `{ code, code_verifier, redirect_uri, nonce? }` | v3.23.0; public clients v3.29.0 | Planned (CON-010). |
| Web OIDC | `GET /api/auth/oauth`, `GET /api/auth/oauth/callback` | — | Cookie-based; not for native apps. |
| Reverse-proxy auth | `GET /api/auth/reverse-proxy` | v3.29.0 | Browser-oriented; native clients should use API tokens. |
| Long-lived API tokens | `POST /api/users/api-tokens`, `DELETE /api/users/api-tokens/{id}` | — | CON-013: users paste a token created in Mealie; Katsu validates it with `GET /api/users/self` and stores it in the Keychain. Cannot be exchanged via `/api/auth/refresh`, so a 401 asks for a new token. Katsu defaults to this method when `allowPasswordLogin` is `false` or `enableReverseProxyAuth` is `true`. |
| LDAP | Transparent through `POST /api/auth/token` | — | Works with CON-002. |

Notes:

- Session tokens expire after `tokenTime` hours (max 87600). Refreshing keeps
  the original `remember_me` choice.
- Native OIDC requires the admin to register Katsu's redirect URI (custom
  scheme) with their identity provider. Google and Microsoft need a separate
  public native client (`OIDC_NATIVE_CLIENT_ID`,
  `OIDC_NATIVE_CONFIDENTIAL=false`). Use `ASWebAuthenticationSession`, not an
  embedded web view, so passkey-only providers work.
- Too many bad passwords lock the account (`SECURITY_MAX_LOGIN_ATTEMPTS`,
  default 5); admins unlock via `POST /api/admin/users/unlock`.

## Users And Households

| Capability | Endpoints |
| --- | --- |
| Current user | `GET /api/users/self` (includes `groupSlug`, `householdSlug`, permission flags, `authMethod`). |
| Ratings / favorites | `GET /api/users/self/ratings[/{recipeId}]`, `GET /api/users/self/favorites`, `POST /api/users/{id}/ratings/{slug}`, `POST\|DELETE /api/users/{id}/favorites/{slug}`. |
| Profile | `PUT /api/users/{id}`, `PUT /api/users/password`, `POST /api/users/{id}/image`, password reset routes. |
| Household | `GET /api/households/self`, `/members`, `/preferences`, `/statistics`, `GET /api/households/self/recipes/{slug}` (household `lastMade`). |
| Group | `GET /api/groups/self`, `/members`, `/preferences`, `/storage`, `GET /api/groups/households`. |
| Invitations | `GET\|POST /api/households/invitations` (GET is admin-only since v3.10.0), `POST .../email`. |

v3.0.0 moved admin user CRUD from `/api/users` to `/api/admin/users`.

## Recipes

| Capability | Endpoints | Since / notes |
| --- | --- | --- |
| List and search | `GET /api/recipes` with `search`, `categories`, `tags`, `tools`, `foods`, `households`, `cookbook`, `requireAll*`, plus pagination params | Rating filter v3.25.0, time filters v3.29.0, sort by total time v3.30.0. |
| Detail | `GET /api/recipes/{slug}` | — |
| Create / update / delete | `POST /api/recipes`, `PUT\|PATCH\|DELETE /api/recipes/{slug}`, bulk `PUT\|PATCH /api/recipes`, `POST /api/recipes/{slug}/duplicate` | After v3.30.0, new recipes no longer get a placeholder ingredient and step. |
| Import from URL | `POST /api/recipes/create/url` with `{ url, includeTags, includeCategories }` → slug; `.../url/stream` (SSE progress); `.../url/bulk` | Categories v3.10.0; progress v3.13.0. |
| Import HTML/JSON | `POST /api/recipes/create/html-or-json[/stream]` | Pasted Mealie export v3.30.0. |
| AI import | `POST /api/recipes/create/ai[/stream]` multipart: `content`, `url`, `images[]`, `translateLanguage`, `createNewOrganizers` | Requires an AI provider. Video URLs (YouTube/TikTok/Instagram) v3.13.0. |
| Zip import | `POST /api/recipes/create/zip` | — |
| Test scrape | `POST /api/recipes/test-scrape-url` | — |
| Images and assets | `POST\|PUT\|DELETE /api/recipes/{slug}/image`, `POST /api/recipes/{slug}/assets[/url]`, media routes above | `DELETE` image v3.5.0. |
| Mark as made | `PATCH /api/recipes/{slug}/last-made` with `{ timestamp }` | — |
| Timeline | `GET\|POST /api/recipes/timeline/events`, `GET\|PUT\|DELETE .../{id}`, `PUT .../{id}/image` | Image management v3.30.0; edits limited to author or admin after v3.30.0. |
| Comments | `GET /api/recipes/{slug}/comments`, `GET\|POST /api/comments`, `GET\|PUT\|DELETE /api/comments/{id}` | — |
| Suggestions ("what can I make") | `GET /api/recipes/suggestions` with `foods`, `tools`, `maxMissingFoods`, `maxMissingTools`, `includeFoodsOnHand`, `includeToolsOnHand`, `includeSubstitutions` | — |
| Share links | `GET\|POST /api/shared/recipes`, `GET\|DELETE /api/shared/recipes/{id}`; public `GET /api/recipes/shared/{token}` | Non-expiring for public groups v3.23.0. |
| Exports | `GET /api/recipes/{slug}/exports[/pdf]`, bulk export routes | — |
| Ingredient parser | `POST /api/parser/ingredient`, `POST /api/parser/ingredients` (`parser`: `nlp`, `brute`, `openai`) | Custom units v3.14.0. |
| Bulk actions | `POST /api/recipes/bulk-actions/{tag,categorize,settings,delete,export}` | — |

### Recipe Schema Highlights

- **Times:** `totalTime`, `prepTime`, and `performTime` are display strings;
  v3.29.0 added structured `totalTimeSeconds`, `prepTimeSeconds`, and
  `performTimeSeconds`. Mealie's "Cook time" UI writes `performTime`.
  `cookTime` is removed after v3.30.0 (#9011), so treat it as optional and
  prefer `performTime`.
- **Instructions:** `RecipeStep` has `title`, `summary`, `text`,
  `ingredientReferences`, `noteReferences` (v3.26.0), and `durationSeconds`
  (v3.30.0).
- **Ingredients:** `quantity`, `unit`, `food`, `note`, `display`,
  `originalText`, `title` (section header, v3.2.0), `referencedRecipe`
  (recipe as ingredient, v3.5.0), and `substitutions[]` (v3.26.0).
- **Units:** `standardQuantity` and `standardUnit` (v3.13.0) power unit
  conversion and the web's metric/imperial toggle (v3.29.0).
- **Owner:** `userId`/`householdId` identify the recipe owner, shown in the
  web UI since v3.30.0.
- **Settings:** `public`, `showNutrition`, `showAssets`, `landscapeView`,
  `disableComments`, `locked`.

## Organizers And Data Management

| Capability | Endpoints |
| --- | --- |
| Categories / tags / tools | `/api/organizers/{categories,tags,tools}` with CRUD, `/slug/{slug}`, `/empty`, `/merge`. Responses include `recipeCount` (v3.25.0). |
| Foods | `/api/foods` CRUD, `/empty`, `PUT /api/foods/merge`. Foods carry `aliases`, `labelId`, `substitutions`, on-hand household data. |
| Units | `/api/units` CRUD and `PUT /api/units/merge`. |
| Labels | `/api/groups/labels` CRUD, `/empty`, `/merge`. |
| Seeders | `POST /api/groups/seeders/{foods,units}` (food seed overhauled in v3.28.0). |
| Migrations | `POST /api/groups/migrations` (`nextcloud`, `chowdown`, `copymethat`, `paprika`, `mealie_alpha`, `tandoor`, `plantoeat`, `myrecipebox`, `recipekeeper`, `cookn`). |

## Meal Plans

| Capability | Endpoints | Since / notes |
| --- | --- | --- |
| List | `GET /api/households/mealplans?start_date=&end_date=&include_week_entries=` | Weekly entries are excluded unless `include_week_entries=true`. |
| Today | `GET /api/households/mealplans/today` | Useful for widgets and intents. |
| CRUD | `POST /api/households/mealplans`, `GET\|PUT\|DELETE .../{id}` | — |
| Random | `POST /api/households/mealplans/random` with `{ date, endDate?, entryType }` | Honors meal plan rules. |
| Rules | `/api/households/mealplans/rules` CRUD | Filters by label, rating, and time added in v3.25.0–v3.29.0. |
| iCal feed | `GET\|POST\|DELETE /api/households/mealplans/ical` manages a token; `GET .../ical/{token}` is an unauthenticated `.ics` feed | v3.29.0; customization v3.30.0. |

`PlanEntryOut` fields: `id`, `date`, `endDate` (weekly entries, v3.30.0),
`entryType` (`breakfast`, `lunch`, `dinner`, `side`, `snack`, `drink`,
`dessert`; the last three arrived in v3.7.0), `title`, `text`, `recipeId`,
`recipeScale` (servings multiplier, v3.29.0), `recipe`, `groupId`, `userId`,
`householdId`, and `updatedAt`.

## Shopping Lists

| Capability | Endpoints | Since / notes |
| --- | --- | --- |
| Lists | `/api/households/shopping/lists` CRUD | `ShoppingListOut` includes `listItems`, `recipeReferences`, `labelSettings`. |
| Label order | `PUT /api/households/shopping/lists/{id}/label-settings` | Drives label sections. |
| Items | `/api/households/shopping/items` CRUD, bulk `PUT\|DELETE`, `POST .../create-bulk` | Mutations return `{ createdItems, updatedItems, deletedItems }` because the server may merge matching items. |
| Add recipe | `POST .../lists/{id}/recipe/{recipeId}` or bulk `POST .../lists/{id}/recipe` with `[{ recipeId, recipeIncrementQuantity, recipeIngredients }]` | Linked-recipe units v3.13.0. |
| Remove recipe | `POST .../lists/{id}/recipe/{recipeId}/delete` | — |

Items carry `quantity`, `unit`, `food`, `note`, `display`, `checked`,
`position`, `labelId`/`label`, `referencedRecipe`, `recipeReferences`, and
`extras`. The v3.29.0 "simple entry" is a web UI pattern: match typed text
against `/api/foods` and create a food-linked item, otherwise a note-only item.

## Cookbooks

`/api/households/cookbooks` CRUD plus bulk `PUT` for ordering, and
`GET .../{id}/pdf`. A cookbook is a saved `queryFilterString`; list its
recipes with `GET /api/recipes?cookbook={slugOrId}`. Cookbooks can filter by food label
(v3.28.0) and time (v3.29.0).

## Household Automation

| Capability | Endpoints |
| --- | --- |
| Webhooks | `/api/households/webhooks` CRUD, `/rerun`, `/{id}/test` |
| Notifiers (Apprise) | `/api/households/events/notifications` CRUD, `/{id}/test` |
| Recipe actions | `/api/households/recipe-actions` CRUD, `POST .../{id}/trigger/{recipeSlug}` |

Since v3.26.0 the server blocks outgoing requests (URL imports, image
downloads, webhooks, recipe actions) to private networks unless the admin sets
`HTTP_ALLOW_LIST`. Katsu should surface "import failed" clearly when users try
to import from LAN-only sites.

## AI Providers

Since v3.19.0 admins configure OpenAI-compatible providers in-app:
`/api/groups/ai-providers/{providers,settings,prompts}` and admin equivalents
under `/api/admin/groups/{groupId}/ai-providers`. Prompt customization arrived
in v3.30.0. AI powers URL/video/image import, the `openai` ingredient parser,
and translation. Katsu only needs to detect failures from AI routes; it should
not manage providers.

## Public Explore API

`/api/explore/groups/{groupSlug}/...` exposes public recipes, cookbooks,
organizers, foods, households, and recipe suggestions without auth when the
group and household are public. This could support a signed-out browse mode.

## Admin-Only

Backups, maintenance, email, group/household/user management, and debug
routes live under `/api/admin`. Katsu does not plan to expose them.

## Compatibility Timeline For Clients

| Version | Change affecting API clients |
| --- | --- |
| v3.0.0 | Admin user routes moved to `/api/admin/users`; Jinja2 template rendering removed. |
| v3.3.0 | `TOKEN_TIME` capped at 87600 hours. |
| v3.5.0 | Recipe zip flow refactored; recipes can be ingredients (`referencedRecipe`). |
| v3.7.0 | `snack`, `drink`, `dessert` meal plan entry types. |
| v3.10.0 | `GET /api/households/invitations` became admin-only. |
| v3.23.0 | Native OIDC endpoints. |
| v3.25.0 | **`GET /api/auth/refresh` removed; use `POST`.** Organizer `recipeCount` and merge endpoints. |
| v3.26.0 | Outbound request SSRF protection (`HTTP_ALLOW_LIST`); ingredient substitutions. |
| v3.29.0 | Structured `*TimeSeconds`, meal plan `recipeScale`, iCal feed, reverse-proxy auth, branding fields in `/api/app/about`. |
| v3.30.0 | Meal plan `endDate` and `include_week_entries`; step `durationSeconds`. |
| after v3.30.0 | `cookTime` removed in favor of `performTime`; stricter cross-group/household write checks. |
