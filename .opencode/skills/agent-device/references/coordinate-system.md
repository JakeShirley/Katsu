# Coordinate System

## When to open this file

Open this file only when you must use raw coordinates instead of selectors or `@ref` targeting.

## Command

Use `./node_modules/.bin/agent-device` from the workspace root in this repo. The shorter `agent-device` form in examples means the same repo-local binary, not a required global install.

## Main commands to reach for first

- `screenshot`
- coordinate-based `click` or `swipe`

## Most common mistake to avoid

Do not assume coordinates mean the same thing across platforms or runs. Prefer selectors and refs first.

## Canonical loop

```bash
./node_modules/.bin/agent-device screenshot /tmp/current-screen.png
./node_modules/.bin/agent-device click 120 240
```

## Rules

- Origin is the top-left of the device screen.
- iOS uses device points.
- Android uses pixels.
- Use screenshots to reason about coordinates before acting.
