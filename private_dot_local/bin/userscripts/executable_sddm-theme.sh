#! /bin/bash

set -euo pipefail

theme_dir="/usr/share/sddm/themes"
config_dir="/etc/sddm.conf.d"
config_file="$config_dir/10-theme.conf"
default_theme="tokyo-night"

if [[ $EUID -eq 0 ]]; then
	echo "❌ do not run this script as root or sudo"
	exit 1
fi

if [[ ! -d "$theme_dir" ]]; then
	echo "❌ missing SDDM theme directory: $theme_dir"
	exit 1
fi

get_current_theme() {
	local current=""

	if [[ -f /etc/sddm.conf ]]; then
		current="$(awk -F= '/^[[:space:]]*Current=/{print $2; exit}' /etc/sddm.conf)"
	fi

	if [[ -z "$current" && -d "$config_dir" ]]; then
		current="$(awk -F= '/^[[:space:]]*Current=/{print $2; exit}' "$config_dir"/*.conf 2>/dev/null || true)"
	fi

	printf "%s" "$current"
}

mapfile -t themes < <(find "$theme_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
if [[ ${#themes[@]} -eq 0 ]]; then
	echo "❌ no SDDM themes found in $theme_dir"
	exit 1
fi

current_theme="$(get_current_theme)"
if [[ -z "$current_theme" ]]; then
	current_theme="$default_theme"
fi

if ! printf '%s\n' "${themes[@]}" | grep -qx "$current_theme"; then
	if printf '%s\n' "${themes[@]}" | grep -qx "$default_theme"; then
		current_theme="$default_theme"
	else
		current_theme="${themes[0]}"
	fi
fi

# --- Theme selection with fzf or fallback ---
if command -v fzf >/dev/null; then
	echo "🎨 Select SDDM theme (current: $current_theme):"
	selected_theme=$(printf '%s\n' "${themes[@]}" | fzf \
		--height=40% \
		--layout=reverse \
		--border \
		--prompt="Theme: " \
		--header="Enter = select, Esc = cancel" \
		--query="" \
		--select-1 \
		--exit-0 \
		--bind="enter:accept" \
		--highlight-line \
		--marker="*" \
		--preview="echo 'Current: $current_theme'" \
	) || selected_theme=""

	if [[ -z "$selected_theme" ]]; then
		echo "❌ No selection made, exiting."
		exit 0
	fi
else
	# Fallback: manual selection
	echo "🎨 Available SDDM themes:"
	for i in "${!themes[@]}"; do
		marker=" "
		if [[ "${themes[$i]}" == "$current_theme" ]]; then
			marker="*"
		fi
		printf " %2d) [%s] %s\n" "$((i + 1))" "$marker" "${themes[$i]}"
	done

	printf "Select theme [Enter keeps %s]: " "$current_theme"
	read -r choice

	selected_theme="$current_theme"
	if [[ -n "$choice" ]]; then
		if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
			echo "❌ invalid selection: $choice"
			exit 1
		fi

		if ((choice < 1 || choice > ${#themes[@]})); then
			echo "❌ invalid selection: $choice"
			exit 1
		fi

		selected_index=$((choice - 1))
		selected_theme="${themes[$selected_index]}"
	fi
fi

# --- Idempotency check ---
if [[ "$selected_theme" == "$current_theme" ]]; then
	echo "✅ Theme '$selected_theme' is already active, no change needed."
	exit 0
fi

# --- Set theme ---
sudo mkdir -p "$config_dir"
printf "[Theme]\nCurrent=%s\n" "$selected_theme" | sudo tee "$config_file" >/dev/null

echo "✅ SDDM theme set to: $selected_theme"
