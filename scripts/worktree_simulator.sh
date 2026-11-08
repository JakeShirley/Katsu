#!/usr/bin/env bash
# Prints the UDID of the iPhone 17 simulator dedicated to the current git
# worktree, creating or reclaiming one if needed.
#
# Each worktree owns a simulator named "Katsu-<worktree directory name>", so
# parallel work streams never share (and clobber) the same device. When no
# simulator carries this worktree's name yet, a "Katsu-*" simulator whose
# worktree no longer exists is renamed and erased for reuse; otherwise a new
# one is created.
#
# Usage:
#   SIM_UDID="$(scripts/worktree_simulator.sh)"           # ensure + boot
#   scripts/worktree_simulator.sh --name                  # print name only
set -euo pipefail

DEVICE_TYPE_ID="com.apple.CoreSimulator.SimDeviceType.iPhone-17"
DEVICE_TYPE_NAME="iPhone 17"

repo_root="$(git rev-parse --show-toplevel)"
sim_name="Katsu-$(basename "$repo_root")"

if [[ "${1:-}" == "--name" ]]; then
  echo "$sim_name"
  exit 0
fi

devices_json="$(xcrun simctl list devices available -j)"

udid="$(jq -r --arg n "$sim_name" \
  '[.devices[][] | select(.name == $n)][0].udid // empty' <<<"$devices_json")"

if [[ -z "$udid" ]]; then
  live_names="$(git worktree list --porcelain \
    | sed -n 's|^worktree ||p' \
    | while read -r path; do echo "Katsu-$(basename "$path")"; done \
    | jq -R . | jq -s .)"

  udid="$(jq -r --arg type "$DEVICE_TYPE_ID" --argjson live "$live_names" '
    [.devices[][]
      | select(.deviceTypeIdentifier == $type)
      | select(.name | startswith("Katsu-"))
      | select(.name as $n | $live | index($n) | not)
    ][0].udid // empty' <<<"$devices_json")"

  if [[ -n "$udid" ]]; then
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid" >/dev/null
    xcrun simctl rename "$udid" "$sim_name"
  else
    udid="$(xcrun simctl create "$sim_name" "$DEVICE_TYPE_NAME")"
  fi
fi

xcrun simctl boot "$udid" >/dev/null 2>&1 || true
echo "$udid"
