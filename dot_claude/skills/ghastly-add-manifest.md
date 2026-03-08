---
name: ghastly-add-manifest
description: Add a ghastly/v1 artifact manifest step to a GitHub Actions workflow so that ghastly can display built artifact versions and references in its detail panel. Use this skill when the user says anything like "ghastly manifest hinzufügen", "ghastly output", "ghastly artefakt", "add ghastly manifest", "ghastly step", or "ghastly-add-manifest". Always invoke this skill for these requests — do not attempt it manually without reading this first.
---

# ghastly-add-manifest

Adds a step to a GitHub Actions workflow that writes a `ghastly/v1` artifact manifest as an HTML comment into `$GITHUB_STEP_SUMMARY`. ghastly reads this comment from the step summary to display artifact versions and references in its detail panel.

---

## The manifest format

ghastly parses the following HTML comment from the step summary (regex: `<!-- ghastly:artifacts\s*([\s\S]*?)-->`):

```
<!-- ghastly:artifacts
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
-->
```

**Field rules:**
- `schema` must be exactly `"ghastly/v1"` — any other value is silently ignored
- `built_at` — ISO 8601 UTC timestamp (use `$(date -u +"%Y-%m-%dT%H:%M:%SZ")` in the step shell)
- `trigger` — GitHub event name (`push`, `pull_request`, `workflow_dispatch`, etc.)
- `artifacts` — array of one or more artifact entries; all four fields per entry are required:
  - `name` — short human-readable identifier (shown in table column)
  - `type` — artifact kind (see type conventions below)
  - `version` — semver or tag, shown as-is
  - `ref` — how to pull/use the artefact; shown as-is in the table

**Type conventions (use these strings):**

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

## Step-by-step process

### Step 1 — Find the workflow file

```bash
ls .github/workflows/
```

Read the relevant workflow file(s). If there are multiple, ask the user which one to modify (or check which one is the main build/release workflow).

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

The manifest step should go **after** the build/push steps succeed but **before** the job ends. Use `if: always()` only if you want the manifest even on partial failure — otherwise omit `if:` so it only runs when all prior steps succeeded.

For release workflows, place it after the push/publish step.

### Step 5 — Write the step YAML

Use this template (adapt the `env:` block and artifact array to what was found in steps 2 and 3):

```yaml
      - name: Write ghastly manifest
        env:
          VERSION: ${{ env.VERSION }}           # adjust to actual version source
          TRIGGER: ${{ github.event_name }}
        run: |
          cat >> "$GITHUB_STEP_SUMMARY" << EOF
          <!-- ghastly:artifacts
          {
            "schema": "ghastly/v1",
            "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "trigger": "$TRIGGER",
            "artifacts": [
              {
                "name": "my-app",
                "type": "docker",
                "version": "$VERSION",
                "ref": "ghcr.io/${{ github.repository }}:$VERSION"
              }
            ]
          }
          -->
          EOF
```

**Important notes on shell quoting:**
- Use `<< EOF` (unquoted) so shell variables (`$VERSION`, `$TRIGGER`) are expanded
- GitHub Actions expressions (`${{ }}`) are evaluated *before* the shell runs, so they can appear inside either heredoc style
- `$(date ...)` inside `<< EOF` is evaluated by the shell at runtime — this is correct
- Do NOT use `<<'EOF'` (single-quoted heredoc) — shell variables would not expand

### Step 6 — Multiple artifacts

If the build produces more than one artifact (e.g., multiple Docker images, or a Docker image + a Helm chart), list them all in the `artifacts` array:

```yaml
        run: |
          cat >> "$GITHUB_STEP_SUMMARY" << EOF
          <!-- ghastly:artifacts
          {
            "schema": "ghastly/v1",
            "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "trigger": "$TRIGGER",
            "artifacts": [
              {
                "name": "api",
                "type": "docker",
                "version": "$VERSION",
                "ref": "ghcr.io/${{ github.repository }}/api:$VERSION"
              },
              {
                "name": "worker",
                "type": "docker",
                "version": "$VERSION",
                "ref": "ghcr.io/${{ github.repository }}/worker:$VERSION"
              }
            ]
          }
          -->
          EOF
```

### Step 7 — Insert the step into the workflow file

Use the Edit tool to insert the step at the correct position. Preserve existing indentation (typically 6 spaces for steps inside a job).

### Step 8 — Verify

After editing, read the modified section back and confirm:
- The YAML indentation is consistent with the surrounding steps
- The `schema` value is exactly `"ghastly/v1"`
- All four artifact fields are present
- The heredoc marker is unquoted (`<< EOF`, not `<<'EOF'`)
- Variable names match what is actually set earlier in the workflow

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
        run: |
          cat >> "$GITHUB_STEP_SUMMARY" << EOF
          <!-- ghastly:artifacts
          {
            "schema": "ghastly/v1",
            "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "trigger": "$TRIGGER",
            "artifacts": [
              {
                "name": "${{ github.event.repository.name }}",
                "type": "docker",
                "version": "$VERSION",
                "ref": "ghcr.io/${{ github.repository }}:$VERSION"
              }
            ]
          }
          -->
          EOF
```

### NuGet package

```yaml
      - name: Write ghastly manifest
        env:
          VERSION: ${{ env.PACKAGE_VERSION }}
          PKG_NAME: MyCompany.MyLib
          TRIGGER: ${{ github.event_name }}
        run: |
          cat >> "$GITHUB_STEP_SUMMARY" << EOF
          <!-- ghastly:artifacts
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
          -->
          EOF
```

### Commit-based (no version tag)

```yaml
      - name: Write ghastly manifest
        env:
          TRIGGER: ${{ github.event_name }}
        run: |
          SHORT_SHA=$(echo "$GITHUB_SHA" | cut -c1-7)
          cat >> "$GITHUB_STEP_SUMMARY" << EOF
          <!-- ghastly:artifacts
          {
            "schema": "ghastly/v1",
            "built_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
            "trigger": "$TRIGGER",
            "artifacts": [
              {
                "name": "${{ github.event.repository.name }}",
                "type": "docker",
                "version": "$SHORT_SHA",
                "ref": "ghcr.io/${{ github.repository }}:$SHORT_SHA"
              }
            ]
          }
          -->
          EOF
```
