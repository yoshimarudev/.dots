#!/usr/bin/env bash
# Focus yabai space N without the scripting addition (SIP enabled).
# macOS 27 broke `yabai -m space --focus` with SIP on, so drive the native
# Mission Control shortcuts instead:
# focus the display (focus-display.sh), then step with ctrl - left/right.
# ctrl - N ("Switch to Desktop N") is tried first; macOS 27 sometimes ignores it until yabai/skhd restart (Oct 2026).

YABAI=/opt/homebrew/bin/yabai
SKHD=/opt/homebrew/bin/skhd
target=$1

# a switch across displays takes ~1s; drop presses that arrive mid-switch
# instead of letting two runs fight over the arrow keys
LOCK=/tmp/yabai-focus-space.$USER.lock
if ! mkdir "$LOCK" 2>/dev/null; then
  # stale lock from a killed run
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +0.1 2>/dev/null)" ] || exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

cur() { $YABAI -m query --spaces --space | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin)["index"])'; }

read -r disp pos < <($YABAI -m query --spaces | /usr/bin/python3 -c '
import sys, json
t = int(sys.argv[1])
sp = json.load(sys.stdin)
s = next((s for s in sp if s["index"] == t), None)
if s: print(s["display"], sum(1 for x in sp if x["display"] == s["display"] and x["index"] <= t))
' "$target")
[ -z "$disp" ] && exit 1
[ "$(cur)" = "$target" ] && exit 0

cur_disp() { $YABAI -m query --spaces --space | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin)["display"])'; }

"$(dirname "$0")/focus-display.sh" "$disp"
# wait until focus has actually landed on that display, or the arrows hit the old one
for _ in $(seq 30); do [ "$(cur_disp)" = "$disp" ] && break; sleep 0.05; done
[ "$(cur_disp)" = "$disp" ] || exit 1
# try the direct jump first (main display, ctrl - 1..5 enabled); fall back to stepping if macOS ignores it
if [ "$disp" = 1 ] && [ "$pos" -le 5 ]; then
  $SKHD -k "ctrl - $pos"
  for _ in $(seq 20); do sleep 0.05; [ "$(cur)" = "$target" ] && exit 0; done
fi
for _ in 1 2 3 4 5 6 7 8 9; do
  c=$(cur)
  [ "$c" = "$target" ] && break
  if [ "$c" -lt "$target" ]; then $SKHD -k "ctrl - right"; else $SKHD -k "ctrl - left"; fi
  # wait for the switch animation to land before stepping again
  moved=
  for _ in $(seq 40); do sleep 0.05; [ "$(cur)" != "$c" ] && moved=1 && break; done
  [ -z "$moved" ] && exit 1   # switch never registered; don't keep pressing blindly
done
