---
name: git-hooks
description: Org git hooks — pre-push (Claude review + risk score) and commit-msg (conventional commit validation). Installed globally via core.hooksPath by install.sh.
---

Hooks live here, symlinked to `~/.git-hooks/` on install.
All repos pick them up automatically via `git config --global core.hooksPath ~/.git-hooks`.

- `pre-push` — runs `pr-review.sh` on every push
- `commit-msg` — validates conventional commit format
- `pr-review.sh` — Claude AI review (Haiku); blocks on `bug:` findings or `REQUEST CHANGES` verdict

Control via env vars:
- `PR_REVIEW_MODE=warn` — never block, print findings only
- `PR_REVIEW_MODE=off` — skip review entirely
