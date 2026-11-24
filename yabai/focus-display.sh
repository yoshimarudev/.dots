#!/usr/bin/env bash
# Focus another display: next | prev | <index>.
# yabai's display --focus needs a focusable window on the target display, so when
# it fails (empty display, or only sticky widgets like Wispr Flow) fall back to
# clicking an empty spot on that display's menu bar, which makes it the active
# display. The click leaves the menu bar in tracking mode (it would swallow the
# next keypress), so press escape right after.
# cliclick reads a leading "-" as relative movement, so coordinates use "=" to
# force absolute (displays left of the main one have negative x).

YABAI=/opt/homebrew/bin/yabai
CLICLICK=/opt/homebrew/bin/cliclick
arg=${1:-next}

read -r target x y w h < <($YABAI -m query --displays | /usr/bin/python3 -c '
import sys, json
arg = sys.argv[1]
ds = sorted(json.load(sys.stdin), key=lambda d: d["index"])
cur = next(i for i, d in enumerate(ds) if d["has-focus"])
if arg == "next":   t = ds[(cur + 1) % len(ds)]
elif arg == "prev": t = ds[(cur - 1) % len(ds)]
else:               t = next(d for d in ds if d["index"] == int(arg))
f = t["frame"]
print(t["index"], int(f["x"]), int(f["y"]), int(f["w"]), int(f["h"]))
' "$arg") || exit 1

focused() { $YABAI -m query --displays --display | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin)["index"])'; }

[ "$(focused)" = "$target" ] && exit 0
$YABAI -m display --focus "$target" 2>/dev/null
sleep 0.15
if [ "$(focused)" != "$target" ]; then
  $CLICLICK "c:=$((x + w / 2)),=$((y + 3))" kp:esc "m:=$((x + w / 2)),=$((y + h / 2))"
else
  $CLICLICK "m:=$((x + w / 2)),=$((y + h / 2))"
fi
