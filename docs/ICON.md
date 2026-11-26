# App Icon

The Katsu app icon is generated with [Icon Kitchen](https://icon.kitchen/).

## Source

Edit the icon at the canonical URL:

<https://icon.kitchen/i/H4sIAAAAAAAAA0WPzQrCMBCE32W9elBLS-nVgy_gTUQSdxuCMVvSxB9K393diphDwsxOPmYneJhQaIRugt7tOXCCDlb9cmAN9u81pkJqxZNc8INJWT-NJA8g9aaELEN_5ShGNjfiki_oo48OZiUd3wPJyCWDnqKGrTv8hKIyD0uRzVKBcFdXEtqqoraxFSrHRBcEU23rL5ReuSQxpln0nbEE3eYkOUzsUSvxKPeTLJznDyfWIxjwAAAA>

This URL captures the current configuration (background, foreground glyph,
padding, color). Katsu uses Xcode's single-size universal iOS app icon slot
(`1024x1024`), so only `AppIcon~ios-marketing.png` from Icon Kitchen's `ios/`
export is needed. Keep the existing `Contents.json` — do not copy Icon
Kitchen's legacy multi-size `Contents.json` or extra PNGs (which include
unused CarPlay and pre-iOS 10 iPad sizes).

## App Store RGB requirement

Icon Kitchen exports PNGs with an RGBA alpha channel even when every pixel is
opaque. App Store Connect rejects app icons with an alpha channel
(**ITMS-90717**), so `AppIcon~ios-marketing.png` must be flattened to an
opaque 24-bit RGB PNG (`hasAlpha: no`) before committing.

## Replacing the icon

Copy the exported 1024×1024 marketing icon, flatten it to opaque RGB, and
verify that no alpha channel remains:

```sh
cp /path/to/IconKitchen-Output/ios/AppIcon~ios-marketing.png \
  src/Katsu/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon~ios-marketing.png

python3 -c '
from PIL import Image
p = "src/Katsu/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon~ios-marketing.png"
Image.open(p).convert("RGB").save(p, format="PNG", optimize=True)
'

sips -g pixelWidth -g pixelHeight -g hasAlpha \
  src/Katsu/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon~ios-marketing.png
```

Confirm the output reports `pixelWidth: 1024`, `pixelHeight: 1024`, and
`hasAlpha: no`. Then rebuild and verify the home screen icon in the simulator.
