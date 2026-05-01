# App Icon

The Katsu app icon is generated with [Icon Kitchen](https://icon.kitchen/).

## Source

Edit the icon at the canonical URL:

<https://icon.kitchen/i/H4sIAAAAAAAAA0WPzQrCMBCE32W9elBLS-nVgy_gTUQSdxuCMVvSxB9K393diphDwsxOPmYneJhQaIRugt7tOXCCDlb9cmAN9u81pkJqxZNc8INJWT-NJA8g9aaELEN_5ShGNjfiki_oo48OZiUd3wPJyCWDnqKGrTv8hKIyD0uRzVKBcFdXEtqqoraxFSrHRBcEU23rL5ReuSQxpln0nbEE3eYkOUzsUSvxKPeTLJznDyfWIxjwAAAA>

This URL captures the current configuration (background, foreground glyph,
padding, color). Updating the icon means: open that URL in Icon Kitchen,
adjust, export the iOS bundle, and replace
`src/Katsu/Resources/Assets.xcassets/AppIcon.appiconset/` with the contents
of the exported `ios/` folder. Keep Icon Kitchen's `Contents.json` so Xcode
picks up every required size.

## Replacing the icon

```sh
rm -rf src/Katsu/Resources/Assets.xcassets/AppIcon.appiconset
cp -R /path/to/IconKitchen-Output/ios src/Katsu/Resources/Assets.xcassets/AppIcon.appiconset
```

Then rebuild and verify the home screen icon in the simulator.
