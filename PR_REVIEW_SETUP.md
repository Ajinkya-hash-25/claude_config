# PR Review Setup

Pre-push guardrail. Runs graph risk analysis + Claude review on changed code before push. Blocks on red bugs or high risk score.

## What It Does

1. Diffs current branch vs base (default: tracked upstream, fallback `origin/master`)
2. Builds code-review-graph, computes risk score
3. Feeds graph analysis + diff to Claude for line-by-line review
4. Blocks push if: risk ≥ 0.7 OR any `🔴 bug:` found OR no verdict returned
5. Appends review to `changes.md`

---

## Prerequisites

### 1. Bash shell
- **Windows:** Git Bash (bundled with Git for Windows) or WSL
- **Mac/Linux:** native bash

### 2. Python 3
Required for JSON parsing.
```bash
python3 --version   # any 3.x
```

### 3. Claude Code CLI
The review step calls `claude -p ...`.
```bash
claude --version
```
Install: https://docs.claude.com/en/docs/claude-code

### 4. uvx (optional, for risk scoring)
Skips risk analysis if absent — review still runs.
```bash
# Install uv (provides uvx)
curl -LsSf https://astral.sh/uv/install.sh | sh
# Windows: irm https://astral.sh/uv/install.ps1 | iex

uvx code-review-graph --version
```

### 5. git (obviously)

---

## Install

### Step 1 — Make script executable
```bash
chmod +x scripts/pr-review.sh
```

### Step 2 — Wire to pre-push hook

Create `.git/hooks/pre-push` with the following content:

```sh
#!/bin/sh
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "master" ]; then
    exit 0
fi

bash scripts/pr-review.sh
EXIT=$?
if [ $EXIT -ne 0 ]; then
    echo "❌ Push blocked: review failed."
    exit 1
fi
```

Behavior:
- Skip review when pushing `master` (exit 0)
- Any other branch → run `scripts/pr-review.sh`
- Non-zero exit → abort push with message

Make it executable:
```bash
chmod +x .git/hooks/pre-push
```

**One-liner install (copy-paste):**
```bash
cat > .git/hooks/pre-push <<'HOOKEOF'
#!/bin/sh
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "master" ]; then
    exit 0
fi

bash scripts/pr-review.sh
EXIT=$?
if [ $EXIT -ne 0 ]; then
    echo "❌ Push blocked: review failed."
    exit 1
fi
HOOKEOF
chmod +x .git/hooks/pre-push
```

> **Note:** `.git/hooks/` is NOT versioned by git. Each clone needs the hook installed once. For team-wide sharing, commit the hook to `scripts/hooks/pre-push` and symlink, or use `husky` / `pre-commit`.

### Step 3 — Verify
```bash
scripts/pr-review.sh
```
Expected on clean branch: `✔ No unpushed changes. Nothing to review.`

---

## Usage

### Automatic (via hook)
```bash
git push
# → pr-review.sh runs → blocks if issues
```

### Manual
```bash
# Review against default base (upstream or origin/master)
scripts/pr-review.sh

# Review against specific base
scripts/pr-review.sh origin/staging
scripts/pr-review.sh main
```

### Override push block
On `REQUEST CHANGES` verdict, script prompts `(y/n)`. On `🔴 bug:` or risk ≥ 0.7, push is hard-blocked — fix and retry.

To bypass hook entirely (emergency only):
```bash
git push --no-verify
```

---

## Output

### Terminal
Colored report — risk score, per-line findings, verdict.

### `changes.md` (repo root)
Every run appends:
```
## PR Review — <timestamp>
**Branch:** `<branch>` → `<base>`
**Risk Score:** <0-1>
**Tokens:** in=<n> out=<n>
### Changed Files
<list>
### Review
<claude output>
```

---

## Configuration

Script is self-contained. Inlined caveman-review skill body (no external path dependency) — portable across machines.

**Env vars:** none required. `$HOME` used for nothing now (skill path was removed).

**Base branch override:** pass as `$1` or rely on `git rev-parse --abbrev-ref --symbolic-full-name @{u}`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `claude: command not found` | Claude Code not installed | Install CLI, verify `claude --version` |
| `python3: command not found` | No Python 3 | Install Python 3, add to PATH |
| `uvx code-review-graph not found, skipping` | uvx missing | Optional — install uv if you want risk scoring |
| `No verdict detected — blocking push` | Claude response malformed | Check Claude auth, retry |
| Hook never runs | `.git/hooks/pre-push` not executable | `chmod +x .git/hooks/pre-push` |
| Windows line endings break script | CRLF in `.sh` | `dos2unix scripts/pr-review.sh` |

---

## Files

- `scripts/pr-review.sh` — main script
- `.git/hooks/pre-push` — hook trigger (user-created, not versioned)
- `changes.md` — review log (gitignored recommended)

---

## Disable

Remove hook:
```bash
rm .git/hooks/pre-push
```
Script remains usable manually.
