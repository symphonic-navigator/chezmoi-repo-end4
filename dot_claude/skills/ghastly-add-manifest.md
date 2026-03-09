---
name: ghastly-add-manifest
description: Add a ghastly/v1 artifact manifest step to a GitHub Actions workflow so that ghastly can display built artifact versions and references in its detail panel. Use this skill when the user says anything like "ghastly manifest hinzufügen", "ghastly output", "ghastly artefakt", "add ghastly manifest", "ghastly step", or "ghastly-add-manifest". Always invoke this skill for these requests — do not attempt it manually without reading this first.
---

# ghastly-add-manifest

Adds two steps to a GitHub Actions workflow job that write a `ghastly/v1` manifest
JSON file and upload it as a GitHub Actions artifact. ghastly downloads this
artifact via the API to display artifact versions and references in its detail panel.

> **Important:** ghastly reads the manifest from a GitHub Actions **artifact**, NOT
> from `$GITHUB_STEP_SUMMARY`. The check-runs API (`output.summary`) is always `null`
> for native Actions jobs — step summaries are not accessible via API.

---

## The manifest format

The manifest is a plain JSON file (e.g. `ghastly-manifest.json`):

```json
{
  "schema": "ghastly/v1",
  "built_at": "2024-01-15T10:30:00Z",
  "trigger": "push",
  "artifacts": [
    {
      "name": "my-app",
      "type": "docker",
      "version": "1.2.3",
      "ref": "ghcr.io/owner/my-app:1.2.3"
    }
  ]
}
```

**Field rules:**
- `schema` must be exactly `"ghastly/v1"` — any other value is silently ignored
- `built_at` — ISO 8601 UTC timestamp (use `$(date -u +"%Y-%m-%dT%H:%M:%SZ")` in shell)
- `trigger` — GitHub event name (`push`, `pull_request`, `workflow_dispatch`, etc.)
- `artifacts` — array of one or more entries; all four fields per entry are required:
  - `name` — short human-readable identifier (shown in table column)
  - `type` — artifact kind (see type conventions below)
  - `version` — semver, tag, or short SHA; shown as-is
  - `ref` — how to pull/use the artefact; shown as-is in the table

**Type conventions:**

| type | example ref |
|------|-------------|
| `docker` | `ghcr.io/owner/repo:1.2.3` |
| `nuget` | `MyCompany.MyLib@1.2.3` |
| `npm` | `@scope/package@1.2.3` |
| `helm` | `oci://registry.example.com/charts/my-chart:1.2.3` |
| `binary` | `https://github.com/owner/repo/releases/tag/v1.2.3` |
| `pypi` | `my-package==1.2.3` |

Use `docker` for any OCI image regardless of registry.

---

## Artifact naming convention

The artifact uploaded to GitHub Actions **must be named with the prefix `ghastly-manifest`**.
ghastly finds it via `startswith("ghastly-manifest")`.

- Single job: use `ghastly-manifest` or `ghastly-manifest-<jobname>`
- Multiple parallel jobs: each job must use a **unique suffix** — artifact names must be
  unique per workflow run:
  - `ghastly-manifest-api`
  - `ghastly-manifest-frontend`
  - `ghastly-manifest-worker`

ghastly downloads **all** matching artifacts and merges their `artifacts` lists into
one table, so all jobs appear together in the detail panel.

---

## Step-by-step process

### Step 1 — Find the workflow file

```bash
ls .github/workflows/
```

Read the relevant workflow file(s). If there are multiple, ask the user which one
to modify (or check which one is the main build/release workflow).

### Step 2 — Identify what the build produces

Read the workflow carefully. Look for:
- `docker build` / `docker push` / `docker/build-push-action` → type: `docker`
- `dotnet pack` / `nuget push` / `NuGet.Commands` → type: `nuget`
- `npm publish` / `yarn publish` → type: `npm`
- `helm push` / `helm package` → type: `helm`
- GitHub Release upload steps → type: `binary`
- `pypi` / `twine upload` → type: `pypi`

### Step 3 — Find where the version is determined

Look for:
- An env var like `VERSION`, `IMAGE_TAG`, `RELEASE_VERSION`, `PACKAGE_VERSION`
- A step output like `steps.some-step.outputs.version`
- `github.ref_name` (for tag-triggered workflows)
- `github.sha` (for commit-based versioning — use short SHA: `$(echo "$GITHUB_SHA" | cut -c1-7)`)
- A call to `git describe --tags`

### Step 4 — Determine correct placement

The two manifest steps go **after** the build/push steps succeed but **before** the
job ends. Use `if: always()` only if the manifest should also be uploaded on failure;
otherwise omit `if:` so it only runs when all prior steps succeed.

### Step 5 — Count jobs and choose artifact name(s)

- If the workflow has **one job** producing artifacts: use `ghastly-manifest` or
  `ghastly-manifest-<something>`.
- If the workflow has **multiple parallel jobs** each producing artifacts: give each
  job a unique suffix (`ghastly-manifest-api`, `ghastly-manifest-frontend`, etc.).

### Step 6 — Write the two steps

Use this template (adapt `env:`, artifact array and artifact name):

```yaml
      - name: Write ghastly manifest
        env:
          VERSION: ${{ env.VERSION }}        # adjust to actual version source
          TRIGGER: ${{ github.event_name }}
          REPO_OWNER: ${{ github.repository_owner }}
        run: |
          cat > ghastly-manifest.json << EOF
          {
            "schema": "ghastly/v1",
            "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "trigger": "$TRIGGER",
            "artifacts": [
              {
                "name": "my-app",
                "type": "docker",
                "version": "$VERSION",
                "ref": "ghcr.io/$REPO_OWNER/my-app:$VERSION"
              }
            ]
          }
          EOF
          cat >> "$GITHUB_STEP_SUMMARY" << EOF
          ## Build complete

          | Field   | Value        |
          |---------|--------------|
          | Image   | my-app       |
          | Version | \`$VERSION\` |
          | Trigger | $TRIGGER     |
          EOF

      - name: Upload ghastly manifest
        uses: actions/upload-artifact@v4
        with:
          name: ghastly-manifest        # add a unique suffix if multiple parallel jobs
          path: ghastly-manifest.json
          retention-days: 7
```

**Important notes on shell quoting:**
- Use `<< EOF` (unquoted) so shell variables (`$VERSION`, `$TRIGGER`) are expanded
- GitHub Actions expressions (`${{ }}`) are evaluated *before* the shell runs — they
  can appear outside the heredoc in `env:` blocks (preferred) or inside `<< EOF`
- `$(date ...)` inside `<< EOF` is evaluated by the shell at runtime — correct
- Do NOT use `<<'EOF'` (single-quoted heredoc) — shell variables would not expand
- The `$GITHUB_STEP_SUMMARY` section is optional but makes the GitHub Actions UI
  nicer; it is NOT read by ghastly

### Step 7 — Multiple artifacts in one job

List them all in the `artifacts` array of the single JSON file:

```yaml
        run: |
          cat > ghastly-manifest.json << EOF
          {
            "schema": "ghastly/v1",
            "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "trigger": "$TRIGGER",
            "artifacts": [
              {
                "name": "api",
                "type": "docker",
                "version": "$VERSION",
                "ref": "ghcr.io/$REPO_OWNER/api:$VERSION"
              },
              {
                "name": "worker",
                "type": "docker",
                "version": "$VERSION",
                "ref": "ghcr.io/$REPO_OWNER/worker:$VERSION"
              }
            ]
          }
          EOF
```

### Step 8 — Insert the steps into the workflow file

Use the Edit tool to insert both steps at the correct position. Preserve existing
indentation (typically 6 spaces for steps inside a job).

### Step 9 — Verify

After editing, read the modified section back and confirm:
- The YAML indentation is consistent with the surrounding steps
- The `schema` value is exactly `"ghastly/v1"`
- All four artifact fields are present per entry
- The heredoc marker is unquoted (`<< EOF`, not `<<'EOF'`)
- Variable names match what is actually set earlier in the workflow
- The artifact `name:` starts with `ghastly-manifest`
- Parallel jobs use unique artifact name suffixes

Report the changes to the user with a brief summary of what was added and where.

---

## Common patterns

### Tag-triggered release with Docker + GHCR

Version comes from the tag (`github.ref_name`):

```yaml
      - name: Write ghastly manifest
        env:
          VERSION: ${{ github.ref_name }}
          TRIGGER: ${{ github.event_name }}
          REPO_OWNER: ${{ github.repository_owner }}
        run: |
          cat > ghastly-manifest.json << EOF
          {
            "schema": "ghastly/v1",
            "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "trigger": "$TRIGGER",
            "artifacts": [
              {
                "name": "${{ github.event.repository.name }}",
                "type": "docker",
                "version": "$VERSION",
                "ref": "ghcr.io/$REPO_OWNER/${{ github.event.repository.name }}:$VERSION"
              }
            ]
          }
          EOF

      - name: Upload ghastly manifest
        uses: actions/upload-artifact@v4
        with:
          name: ghastly-manifest
          path: ghastly-manifest.json
          retention-days: 7
```

### NuGet package

```yaml
      - name: Write ghastly manifest
        env:
          VERSION: ${{ env.PACKAGE_VERSION }}
          PKG_NAME: MyCompany.MyLib
          TRIGGER: ${{ github.event_name }}
        run: |
          cat > ghastly-manifest.json << EOF
          {
            "schema": "ghastly/v1",
            "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "trigger": "$TRIGGER",
            "artifacts": [
              {
                "name": "$PKG_NAME",
                "type": "nuget",
                "version": "$VERSION",
                "ref": "$PKG_NAME@$VERSION"
              }
            ]
          }
          EOF

      - name: Upload ghastly manifest
        uses: actions/upload-artifact@v4
        with:
          name: ghastly-manifest
          path: ghastly-manifest.json
          retention-days: 7
```

### Commit-based (no version tag)

```yaml
      - name: Write ghastly manifest
        env:
          TRIGGER: ${{ github.event_name }}
          REPO_OWNER: ${{ github.repository_owner }}
        run: |
          SHORT_SHA=$(echo "$GITHUB_SHA" | cut -c1-7)
          cat > ghastly-manifest.json << EOF
          {
            "schema": "ghastly/v1",
            "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "trigger": "$TRIGGER",
            "artifacts": [
              {
                "name": "${{ github.event.repository.name }}",
                "type": "docker",
                "version": "$SHORT_SHA",
                "ref": "ghcr.io/$REPO_OWNER/${{ github.event.repository.name }}:$SHORT_SHA"
              }
            ]
          }
          EOF

      - name: Upload ghastly manifest
        uses: actions/upload-artifact@v4
        with:
          name: ghastly-manifest
          path: ghastly-manifest.json
          retention-days: 7
```

### Two parallel jobs (e.g. api + frontend)

Each job gets a unique artifact suffix so they don't conflict:

```yaml
# in build-api job:
      - name: Upload ghastly manifest
        uses: actions/upload-artifact@v4
        with:
          name: ghastly-manifest-api
          path: ghastly-manifest.json
          retention-days: 7

# in build-frontend job:
      - name: Upload ghastly manifest
        uses: actions/upload-artifact@v4
        with:
          name: ghastly-manifest-frontend
          path: ghastly-manifest.json
          retention-days: 7
```

ghastly merges both into a single artifact table.
