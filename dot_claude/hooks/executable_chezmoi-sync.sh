#!/usr/bin/env bash
# Automatically runs `chezmoi add` after Claude edits a file managed by chezmoi.

input=$(cat)
file=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[[ -z "$file" ]] && exit 0

# Resolve to absolute path if needed
file=$(realpath -m "$file" 2>/dev/null || echo "$file")

# Check if chezmoi manages this file
if chezmoi source-path "$file" &>/dev/null; then
    chezmoi add "$file"
fi
