#!/usr/bin/env bash
input=$(cat)

# Resolve cwd: prefer workspace.current_dir, fall back to top-level cwd
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
user=$(whoami)
host=$(hostname -s)

# --- Model segment ---
# Display name from the model field
model_name=$(echo "$input" | jq -r '.model.display_name // ""')

# Output style (e.g. "Explanatory", "Learning") — shown if not the default
output_style=$(echo "$input" | jq -r '.output_style.name // ""')

model_part=""
if [ -n "$model_name" ]; then
    model_part="$model_name"

    # Append output style only when it is set and not the plain default
    if [ -n "$output_style" ] && [ "$output_style" != "default" ] && [ "$output_style" != "Default" ]; then
        model_part="${model_part} (${output_style})"
    fi
fi

# --- Git branch and status indicators ---
git_part=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
             || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

    if [ -n "$branch" ]; then
        # Collect status indicators
        porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
        indicators=""

        # Staged changes
        if echo "$porcelain" | grep -q '^[MADRC]'; then
            indicators="${indicators}+"
        fi
        # Unstaged modifications / deletions
        if echo "$porcelain" | grep -q '^.[MD]'; then
            indicators="${indicators}!"
        fi
        # Untracked files
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

# --- Context window fill level ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
    ctx_display=$(printf "ctx %d%%" "$(printf "%.0f" "$used_pct")")
else
    ctx_display="ctx -"
fi

# --- Assemble: model | user@host | pwd | branch [indicators] | ctx % ---
# Start with model if available
if [ -n "$model_part" ]; then
    line="${model_part} | ${user}@${host} | ${cwd}"
else
    line="${user}@${host} | ${cwd}"
fi

if [ -n "$git_part" ]; then
    line="${line} | ${git_part}"
fi

line="${line} | ${ctx_display}"

printf "%s" "$line"
