# Katsu Privacy Policy

Katsu is an open-source iOS companion app for self-hosted [Mealie](https://docs.mealie.io/) recipe servers. Katsu does not operate any backend services of its own and is built to keep your data under your control.

## Data Collection and Tracking

Katsu's developer does **not** collect, receive, sell, or share any personal data, usage analytics, telemetry, crash reports, or advertising identifiers. Information needed to connect to your Mealie server (such as your server URL, username, credentials, and cached recipes) is stored only on your device and exchanged directly with your configured Mealie server, as described below.

- No third-party analytics, advertising, or tracking SDKs are included in Katsu.
- Katsu does not track you across apps or websites.
- Katsu uses only native Apple system frameworks.

## Direct Communication with Your Mealie Server

All recipe, meal plan, shopping list, favorite, rating, and account data is exchanged directly between your device and the Mealie server(s) you configure.

- Katsu's developer never receives or has access to your server URL, credentials, or Mealie content.
- Data sent to your Mealie server is governed by the privacy and retention policies of that server's administrator (typically you).

## On-Device Storage

To provide fast sign-in and offline access, Katsu stores the following information locally on your device:

- **iOS Keychain**: Your Mealie login credentials, OAuth2 access tokens, and API tokens are stored in the iOS Keychain, scoped per server profile.
- **UserDefaults**: Configured server profiles (server name, URL, authentication method, and last username) and app preferences (such as tab layout) are stored locally in `UserDefaults`.
- **Offline Recipe Cache**: Downloaded recipes, recipe images and assets, and cached favorites are stored locally in the app's Application Support directory so you can browse recipes without a network connection.

You can delete cached offline recipes at any time in **Settings → Offline Recipes → Storage → Clear Offline Recipes**, or remove a server profile and its stored Keychain credentials in **Settings → Servers**. Deleting the app removes its sandboxed local data (`UserDefaults` and the offline recipe cache), though iOS Keychain items may persist across app deletion; remove your server profiles in **Settings → Servers** before deleting the app if you want to clear stored credentials and tokens.

## Camera, Photos, and On-Device Recipe Scanning

Katsu requests camera access or lets you choose images through the system photo picker only when you import a recipe from photos:

- Scanning and text recognition (Apple VisionKit and Vision) and recipe structuring (Apple on-device Foundation Models / Apple Intelligence, when available) run entirely on your device.
- Photos never leave your device during scanning, OCR, or draft review.
- Photos are uploaded only to your own Mealie server if you explicitly import the reviewed recipe with photo attachment or recipe image options enabled.

## Local Notifications

If you start a cooking timer in Making Mode, Katsu schedules local notifications on your device to alert you when the timer finishes. No remote push notification servers are used.

## Children's Privacy

Because Katsu's developer collects no personal information from anyone, Katsu does not knowingly collect personal information from children under 13.

## Changes to This Policy

If Katsu's privacy practices ever change, this document will be updated in the Katsu repository before those changes ship.

## Support and Contact

If you have questions about this privacy policy or need help with Katsu, please open an issue on GitHub:

- https://github.com/JakeShirley/Katsu/issues
