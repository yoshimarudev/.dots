#!/bin/bash
# Claude Code statusline
# Order: folder -> rate-limit bar -> branch -> model·effort -> context
# Plain 8-color ANSI only (no 256/truecolor), so it adapts to the terminal theme.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir')
repo=$(echo "$input" | jq -r '.workspace.repo | if . then .owner + "/" + .name else empty end')
model=$(echo "$input" | jq -r '.model.display_name')
effort=$(echo "$input" | jq -r '.effort.level // empty')
context_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

YELLOW="\033[33m"
CYAN="\033[36m"
MAGENTA="\033[35m"
DIM="\033[2m"
RESET="\033[0m"

# >= 80% red, >= 50% yellow, else green
threshold_color() {
  local pct=$1
  if [ "$pct" -ge 80 ]; then
    printf '\033[31m'
  elif [ "$pct" -ge 50 ]; then
    printf '\033[33m'
  else
    printf '\033[32m'
  fi
}

# [####------] 42%
bar() {
  local pct=$1 width=10 filled i out=""
  filled=$((pct * width / 100))
  [ "$filled" -gt "$width" ] && filled=$width
  for ((i = 0; i < width; i++)); do
    if [ "$i" -lt "$filled" ]; then out="$out#"; else out="$out-"; fi
  done
  printf '[%s] %d%%' "$out" "$pct"
}

# 1. Folder or git repo
if [ -n "$repo" ]; then
  folder="$repo"
else
  folder=$(basename "$cwd")
fi

# 2. Rate-limit bar (5h window)
usage=""
if [ -n "$five" ]; then
  fivepct=$(printf '%.0f' "$five")
  usage="$(threshold_color "$fivepct")$(bar "$fivepct")${RESET}"
fi

# 3. Git branch
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

# 4. Model, with reasoning effort appended after a dim dot
modelseg="${MAGENTA}${model}${RESET}"
if [ -n "$effort" ]; then
  modelseg="${modelseg} ${DIM}·${RESET} ${MAGENTA}${effort}${RESET}"
fi

# 5. Context window usage
ctx=""
if [ -n "$context_pct" ]; then
  ctxpct=$(printf '%.0f' "$context_pct")
  ctx="$(threshold_color "$ctxpct")ctx:${ctxpct}%${RESET}"
fi

parts=()
parts+=("${YELLOW}${folder}${RESET}")
[ -n "$usage" ] && parts+=("$usage")
[ -n "$branch" ] && parts+=("${CYAN}${branch}${RESET}")
parts+=("$modelseg")
[ -n "$ctx" ] && parts+=("$ctx")

output=""
for i in "${!parts[@]}"; do
  if [ "$i" -eq 0 ]; then
    output="${parts[$i]}"
  else
    output="${output} ${DIM}|${RESET} ${parts[$i]}"
  fi
done

printf "%b\n" "$output"
