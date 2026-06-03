# Org Claude Config

Low-friction Claude/Codex config for dev teams: graph-first navigation, reuse checks, stack standards, review guardrails, and token discipline.

## Quickstart

```bash
./install.sh --all
python scripts/doctor.py
python scripts/prompt-bench.py
```

Windows:

```powershell
.\install.ps1 -All
python .\scripts\doctor.py
python .\scripts\prompt-bench.py
```

## What ships

- `AGENTS.md` / `CLAUDE.md` - org behavior rules.
- `agents/` - focused subagents for explore, plan, reuse, security, test cases.
- `skills/` - code review, PR text, scaffolds, endpoint docs, flow diagrams.
- `standards/` - stack-specific coding standards.
- `settings.json` - graph update hook after edits only.
- `mcp.json` - code-review-graph MCP.
- `scripts/pr-review.sh` - capped pre-push AI review.
- `scripts/doctor.py` - install and health checks.
- `scripts/prompt-bench.py` - prompt/token benchmark.

## Install Modes

```bash
./install.sh          # Claude config only
./install.sh --git    # git hooks only
./install.sh --all    # config + hooks
```

```powershell
.\install.ps1         # Claude config only
.\install.ps1 -Git    # git hooks only
.\install.ps1 -All    # config + hooks
.\install.ps1 -Copy   # copy instead of symlink
```

## Review Hook

`scripts/pr-review.sh` compares current branch against upstream, then `origin/main`, then `origin/master`, then `HEAD~1`.

Env:

```bash
PR_REVIEW_MODE=block          # default: block high risk / bugs / no verdict
PR_REVIEW_MODE=warn           # report only
PR_REVIEW_MODE=off            # skip
PR_REVIEW_MAX_DIFF_LINES=500  # diff cap
PR_REVIEW_MAX_FILES=30        # file cap
```

## Health Check

```bash
python scripts/doctor.py
python scripts/doctor.py --deep
```

`--deep` checks external graph commands too. Use normal mode for fast local validation.

## Prompt Bench

```bash
python scripts/prompt-bench.py
python scripts/prompt-bench.py --run
```

Dry-run estimates context/prompt tokens. `--run` calls Claude CLI and writes usage to `prompt-bench.md`.
