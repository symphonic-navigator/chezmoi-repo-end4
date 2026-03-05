---
name: setup-obsidian-vault-for-repo
description: Set up an Obsidian vault inside a repository, creating a structured documentation layout and linking CLAUDE.md into the vault. Use this skill whenever the user wants to add an Obsidian vault to a repo, set up repo documentation in Obsidian, initialize a project vault, or says anything like "obsidian vault anlegen", "vault setup", "obsidian ins repo", or "setup-obsidian-vault-for-repo". Always use this skill for these requests — don't try to do it manually without reading this first.
---

# setup-obsidian-vault-for-repo

Sets up a fully structured Obsidian vault inside a repository, with a symlink from the repo root's `CLAUDE.md` into the vault. This ensures both Obsidian and Claude Code work seamlessly from the same source of truth.

---

## What this skill does

1. Creates `./obsidian/` as the Obsidian vault root
2. Checks if `./CLAUDE.md` exists:
   - **If it exists**: moves it into the vault, creates a symlink at repo root pointing to `./obsidian/CLAUDE.md`
   - **If it does NOT exist**: creates a minimal placeholder `./obsidian/CLAUDE.md` and symlinks it, with a note to run `/init`
3. Creates the full directory structure with `.gitkeep` files
4. Creates the Obsidian config directory (`.obsidian/`) so the vault is recognized immediately

---

## Directory structure to create

```
obsidian/
├── .obsidian/                        ← Obsidian config dir (makes it a valid vault)
│   └── .gitkeep
├── CLAUDE.md                         ← The real CLAUDE.md lives here
├── Documentation/
│   ├── Architecture/
│   │   └── .gitkeep
│   └── Details/
│       └── .gitkeep
├── Examples/
│   └── .gitkeep
├── API/
│   └── .gitkeep
├── Ideas/
│   └── .gitkeep
└── Current Implementation/
    └── .gitkeep
```

And in the repo root:
```
CLAUDE.md -> obsidian/CLAUDE.md       ← symlink
```

---

## Step-by-step instructions

### Step 1 — Check preconditions

```bash
# Are we in a git repo root?
[ -f .git/config ] || echo "WARNING: not a git repo root"

# Does CLAUDE.md already exist?
[ -f CLAUDE.md ] && echo "EXISTS" || echo "MISSING"

# Is it already a symlink?
[ -L CLAUDE.md ] && echo "ALREADY_SYMLINK"
```

If `CLAUDE.md` is already a symlink pointing into `obsidian/`, the vault may already be set up — check and report to the user before proceeding.

### Step 2 — Create vault directory structure

```bash
mkdir -p obsidian/.obsidian
mkdir -p "obsidian/Documentation/Architecture"
mkdir -p "obsidian/Documentation/Details"
mkdir -p "obsidian/Examples"
mkdir -p "obsidian/API"
mkdir -p "obsidian/Ideas"
mkdir -p "obsidian/Current Implementation"

touch obsidian/.obsidian/.gitkeep
touch "obsidian/Documentation/Architecture/.gitkeep"
touch "obsidian/Documentation/Details/.gitkeep"
touch "obsidian/Examples/.gitkeep"
touch "obsidian/API/.gitkeep"
touch "obsidian/Ideas/.gitkeep"
touch "obsidian/Current Implementation/.gitkeep"
```

### Step 3 — Handle CLAUDE.md

**If `CLAUDE.md` exists and is NOT a symlink:**
```bash
mv CLAUDE.md obsidian/CLAUDE.md
ln -s obsidian/CLAUDE.md CLAUDE.md
```

**If `CLAUDE.md` does NOT exist:**
```bash
cat > obsidian/CLAUDE.md << 'EOF'
# Project

> ⚠️ This file was auto-created by the `setup-obsidian-vault-for-repo` skill.
> Please run `/init` to populate it with project-specific content.
EOF

ln -s obsidian/CLAUDE.md CLAUDE.md
```

**If `CLAUDE.md` is already a symlink pointing to `obsidian/CLAUDE.md`:**
→ Skip, nothing to do. Report to user.

### Step 4 — Verify

```bash
# Confirm symlink is correct
ls -la CLAUDE.md

# Confirm vault structure
find obsidian -type f | sort
```

Report the result clearly to the user.

---

## Notes

- The `obsidian/` directory should be committed to git — it's part of the project documentation
- The `.obsidian/` subdirectory contains Obsidian workspace config; it's fine to commit the `.gitkeep` but real Obsidian config files (`.obsidian/workspace.json` etc.) may be added to `.gitignore` depending on team preference
- `Current Implementation/` uses a space in the name intentionally — this is fine for Obsidian and for bash (always quote paths)
- This skill does **not** run `/init` — that's a Claude Code built-in slash command the user should run manually when ready
