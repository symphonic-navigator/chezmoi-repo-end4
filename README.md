# end-4 overlay (chezmoi)

This repo is a personal overlay on top of the end-4 / illogical impulse dotfiles. I shared it in the end-4 Discord as a standalone repo to make it easier for folks to try or reference.

The baseline assumption is a **CachyOS headless** install with `yay` already present.

## What this repo does

- Adds my tweaks and package flow on top of end-4 / illogical impulse.
- Installs my custom **de_AT (nodeadkeys)** keyboard layout (`de_at_enhanced`) and wires it into Hyprland.
- Bootstraps **LazyVim MUA (Minimal Usage Agreement)**. Yes, it's installed and kept updated.
- Provides `setup-local` and `update-local` to bootstrap and update a machine.

## Install

Use `chezmoi` to apply the repo. Example:

```bash
chezmoi init --apply <this-repo>
```

On the **first** `chezmoi apply`, `setup-local` runs automatically via `scripts/run_once_after_90.sh.tmpl`:

```bash
~/.local/bin/userscripts/setup-local.sh --nochezmoi --quick
```

That initial run creates `~/.config/local-system.conf` and sets up base system bits before calling `update-local`.

## setup-local

`setup-local` is the first-run bootstrapper:

- Asks which package groups to install (personal, gaming, toys).
- Sets up ssh-agent as a user service.
- Installs prerequisites (flatpak, pyprland, flathub) and docker.
- Calls `update-local` with the same args.

Run it manually any time you want a clean re-bootstrap:

```bash
~/.local/bin/userscripts/setup-local.sh
```

## update-local

`update-local` is the regular update runner. It:

- Updates system packages (pacman + yay) and optional package groups.
- Installs hyprwalz, SDDM themes, and other extras.
- Updates LazyVim.
- Updates this chezmoi repo (unless `--nochezmoi`).
- Optionally updates the end-4 dotfiles repo at `~/repos/dots-hyprland` (unless `--quick`).

Common options:

- `--quick` : skip end-4 dotfiles update.
- `--nochezmoi` : skip `chezmoi update --force`.
- `--sync` : refresh package sources first.

Run it any time after `setup-local`:

```bash
~/.local/bin/userscripts/update-local.sh
```

## Keyboard layout (de_AT, nodeadkeys)

The custom layout lives at:

- `dot_xkb/symbols/de_at_enhanced`

It is based on `at(nodeadkeys)` and adds AltGr mappings for bracket/brace access. Hyprland uses it here:

- `dot_config/hypr/custom/general.conf`

If you do nothing, the layout is already referenced via `kb_layout = de_at_enhanced` once this repo is applied.

## LazyVim

LazyVim is installed/updated automatically:

- First run: `scripts/run_once_before_00.sh.tmpl`
- Updates: `~/.local/bin/userscripts/update-local.sh` via `scripts/update-lazyvim.sh`

Result: `~/.config/nvim` becomes a LazyVim starter checkout, then gets synced on updates.

