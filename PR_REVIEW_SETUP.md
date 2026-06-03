# PR Review Setup

Pre-push guardrail. Runs graph risk analysis + capped Claude review before push.

## What It Does

1. Diffs current branch vs base: upstream, `origin/main`, `origin/master`, then `HEAD~1`.
2. Builds code-review-graph when `uvx` exists.
3. Sends redacted, capped diff to Claude.
4. Blocks in `PR_REVIEW_MODE=block` when risk >= 0.7, a `bug:` finding appears, no verdict appears, or verdict requests changes.
5. Appends review to `changes.md`.

## Install

```bash
./install.sh --git
```

Windows:

```powershell
.\install.ps1 -Git
```

Manual:

```bash
chmod +x scripts/pr-review.sh scripts/pre-push
ln -sf "$PWD/scripts/pre-push" .git/hooks/pre-push
```

## Usage

```bash
scripts/pr-review.sh
scripts/pr-review.sh origin/staging
```

Hook runs automatically on:

```bash
git push
```

## Configuration

```bash
PR_REVIEW_MODE=block          # default: block push on red signals
PR_REVIEW_MODE=warn           # never block
PR_REVIEW_MODE=off            # skip
PR_REVIEW_MAX_DIFF_LINES=500  # cap prompt size
PR_REVIEW_MAX_FILES=30        # cap files
PR_REVIEW_LOG=changes.md      # output log
```

## Prereqs

- Bash: Git Bash, WSL, macOS, Linux.
- Python 3: JSON parsing.
- Claude CLI: AI review.
- uvx: optional graph risk scoring.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `claude CLI not found` | Claude missing from PATH | Install/login to Claude CLI |
| `uvx ... not found` | Graph unavailable | Install uv or accept diff-only review |
| Hook cannot find review script | broken symlink/path | rerun `./install.sh --git` |
| Push blocked but urgent | strict mode | `PR_REVIEW_MODE=warn git push` |
| CRLF breaks script | shell line endings | keep `.gitattributes`, run `git add --renormalize .` |
