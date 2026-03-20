#!/usr/bin/env bash
input=$(cat)

# Resolve cwd: prefer workspace.current_dir, fall back to top-level cwd
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
user=$(whoami)
host=$(hostname -s)

# --- Git branch and status indicators ---
git_part=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
             || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

    if [ -n "$branch" ]; then
        porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
        indicators=""

        if echo "$porcelain" | grep -q '^[MADRC]'; then
            indicators="${indicators}+"
        fi
        if echo "$porcelain" | grep -q '^.[MD]'; then
            indicators="${indicators}!"
        fi
        if echo "$porcelain" | grep -q '^??'; then
            indicators="${indicators}?"
        fi

        if [ -n "$indicators" ]; then
            git_part="${branch} [${indicators}]"
        else
            git_part="${branch}"
        fi
    fi
fi

# --- Model ---
model_name=$(echo "$input" | jq -r '.model.display_name // ""')

# --- Rate limits (5h and 7d windows) ---
# Try array format: [{window:"5h", used_percentage:...}, {window:"7d", ...}]
rl_5h=$(echo "$input" | jq -r '
  (.rate_limits // [])
  | if type == "array" then
      (map(select(.window == "5h" or .window == "five_hour")) | first | .used_percentage // empty)
    else
      (.["5h"].used_percentage // .five_hour.used_percentage // empty)
    end
' 2>/dev/null)

rl_7d=$(echo "$input" | jq -r '
  (.rate_limits // [])
  | if type == "array" then
      (map(select(.window == "7d" or .window == "seven_day")) | first | .used_percentage // empty)
    else
      (.["7d"].used_percentage // .seven_day.used_percentage // empty)
    end
' 2>/dev/null)

if [ -n "$rl_5h" ] && [ "$rl_5h" != "null" ]; then
    rl_5h_display=$(printf "%d%%" "$(printf "%.0f" "$rl_5h")")
else
    rl_5h_display="-"
fi

if [ -n "$rl_7d" ] && [ "$rl_7d" != "null" ]; then
    rl_7d_display=$(printf "%d%%" "$(printf "%.0f" "$rl_7d")")
else
    rl_7d_display="-"
fi

# --- Context window fill ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
    ctx_display=$(printf "ctx %d%%" "$(printf "%.0f" "$used_pct")")
else
    ctx_display="ctx -"
fi

# --- Line 1: user@host | cwd | branch ---
line1="${user}@${host} | ${cwd}"
if [ -n "$git_part" ]; then
    line1="${line1} | ${git_part}"
fi

# --- Line 2: model | 5h X% w X% | ctx X% ---
line2=""
if [ -n "$model_name" ]; then
    line2="${model_name}"
fi
line2="${line2} | 5h ${rl_5h_display} w ${rl_7d_display} | ${ctx_display}"

printf "%s\n%s" "$line1" "$line2"
