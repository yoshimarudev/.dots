#!/bin/bash
# Once per session: remind to use codegraph before grepping in more_connected repos.
in=$(cat)
cwd=$(jq -r '.cwd // ""' <<<"$in"); sid=$(jq -r '.session_id // "x"' <<<"$in")
[[ "$cwd" == */projects/more_connected* ]] || exit 0
tool=$(jq -r '.tool_name' <<<"$in")
if [[ "$tool" == Bash ]]; then
  jq -r '.tool_input.command' <<<"$in" | grep -qE '(^|[|;& ])(grep|rg|find|git ls-files)( |$)' || exit 0
fi
mark="${TMPDIR:-/tmp}/codegraph-nudge-$sid"; [[ -e "$mark" ]] && exit 0; touch "$mark"
jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:"Reminder: these repos are indexed by codegraph (auto-synced). To LOCATE code, use the codegraph_explore MCP tool or `codegraph explore \"<area>\"` / `codegraph node <Symbol>` from the repo dir before grep/find. Grep is fine for exact-string checks once you know where to look."}}'
