#!/usr/bin/env python3
"""Backfill Katsu Localizable.xcstrings.

Ensures every entry has at least a `needs_review` placeholder for es/de/ja so
the catalog stays well-formed as new English source strings are added. Real
translations should be filled in by hand (or via a localization vendor) and
moved from `state: needs_review` to `state: translated`.

Usage:
    python3 scripts/backfill_localizations.py
"""

import json
from pathlib import Path

CATALOG = Path("src/Katsu/Resources/Localizable.xcstrings")
LANGS = ("es", "de", "ja")


def main() -> None:
    catalog = json.loads(CATALOG.read_text())
    strings = catalog.setdefault("strings", {})

    drop_keys = [k for k in strings if k == "" or "%arg" in k]
    for k in drop_keys:
        del strings[k]

    missing: dict[str, list[str]] = {lang: [] for lang in LANGS}
    for key, entry in strings.items():
        localizations = entry.setdefault("localizations", {})
        if "en" not in localizations:
            localizations["en"] = {
                "stringUnit": {"state": "translated", "value": key}
            }
        for lang in LANGS:
            existing = localizations.get(lang)
            existing_value = existing.get("stringUnit", {}).get("value") if existing else None
            if existing_value:
                continue
            missing[lang].append(key)
            localizations[lang] = {
                "stringUnit": {"state": "needs_review", "value": key}
            }
        entry.setdefault("extractionState", "manual")

    CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")

    for lang, keys in missing.items():
        if keys:
            print(f"[{lang}] {len(keys)} entries marked needs_review")


if __name__ == "__main__":
    main()
