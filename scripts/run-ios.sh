#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
export PATH="$HOME/.local/share/flutter/bin:$HOME/.gem/ruby/2.6.0/bin:$PATH"

if ! command -v flutter >/dev/null || ! command -v pod >/dev/null; then
  echo "Flutter and CocoaPods must be installed. See docs/IOS_TESTING.md."
  exit 1
fi

if [[ -n "${1:-}" ]]; then
  simulator_id="$1"
  shift
else
  simulator_id="$(xcrun simctl list devices booted --json | python3 -c '
import json, sys
devices = [d for group in json.load(sys.stdin)["devices"].values() for d in group if d["state"] == "Booted" and d["name"].startswith("iPhone")]
if len(devices) != 1:
    sys.exit("Boot one iPhone in Xcode Device Hub/Simulator, or pass its UUID to this script.")
print(devices[0]["udid"])
')"
fi

exec flutter run --no-pub -d "$simulator_id" "$@"
