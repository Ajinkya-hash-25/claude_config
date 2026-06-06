# Org Claude Config

Graph-first Claude config for dev teams: reuse checks, stack standards, review guardrails, token discipline.

## Install

```bash
git clone <repo> ~/org-claude-config
cd ~/org-claude-config
./install.sh
```

Installs (symlinked — `git pull` auto-reflects):
- `CLAUDE.md` → `~/.claude/CLAUDE.md`
- `skills/` / `agents/` / `commands/` → `~/.claude/`
- git hooks → `~/.git-hooks/` + sets `git config --global core.hooksPath`

Dependencies (checked, not auto-installed):
- `caveman` — `curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash`
- `uvx` — `irm https://astral.sh/uv/install.ps1 | iex` (Win) / `curl -LsSf https://astral.sh/uv/install.sh | sh`
- `code-review-graph` — `pip install code-review-graph`

## Uninstall

```bash
./uninstall.sh
```

Removes symlinks, unsets `core.hooksPath`. Leaves `~/.claude/CLAUDE.md` and `settings.json` untouched.

## Health Check

```bash
python3 skills/doctor/doctor.py          # fast local check
python3 skills/doctor/doctor.py --deep   # + external (uvx, graph)
```

## Prompt Bench

```bash
python3 skills/prompt-bench/prompt-bench.py        # dry-run token estimate
python3 skills/prompt-bench/prompt-bench.py --run  # call Claude, write prompt-bench.md
```

## What Ships

| Path | Purpose |
|---|---|
| `CLAUDE.md` / `AGENTS.md` | Org behavior rules |
| `agents/` | Subagents: explore, plan, reuse, security, test-cases |
| `skills/` | Code review, PR gen, scaffolds, endpoint docs, flow diagrams |
| `skills/git-hooks/` | pre-push AI review + commit-msg validator |
| `skills/doctor/` | Install health check |
| `skills/prompt-bench/` | Token benchmark |
| `standards/` | Stack-specific coding standards (copy as `CLAUDE.md` in project root) |
| `settings.json` | Graph update hook on Edit/Write |
| `mcp.json` | code-review-graph MCP config |

## Git Hooks

Hooks live in `skills/git-hooks/`, symlinked to `~/.git-hooks/`. All repos pick them up automatically via `core.hooksPath`.

**pre-push** — runs `pr-review.sh`: diffs branch vs base, redacts secrets, sends diff to Claude (Haiku), blocks on `bug:` findings or `REQUEST CHANGES` verdict. Shows spinner while reviewing; prompts "Push anyway?" only when blocked.

**commit-msg** — validates conventional commit format: `type(scope): description`.

Control via env:

```bash
PR_REVIEW_MODE=block          # default — block on red signals
PR_REVIEW_MODE=warn           # report only, never block
PR_REVIEW_MODE=off            # skip entirely
PR_REVIEW_MAX_DIFF_LINES=500  # diff cap (default 500)
PR_REVIEW_MAX_FILES=30        # file cap (default 30)
PR_REVIEW_LOG=changes.md      # review log output
```

Override for one push:

```bash
PR_REVIEW_MODE=warn git push
```

## Statusline

Token usage per session: `[in:18k hit:16.9M new:2k out:153k]`

Wire into `~/.claude/settings.json` (path auto-available after install):

```json
{
  "statusLine": {
    "type": "command",
    "command": "python3 ~/.claude/skills/statusline/statusline_tokens.py"
  }
}
```

Windows:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -NonInteractive -Command \"& python '$env:USERPROFILE/.claude/skills/statusline/statusline_tokens.py'\""
  }
}
```

Alt — `ccusage` (shows cost + burn rate):

```json
{ "statusLine": { "type": "command", "command": "bunx ccusage statusline" } }
```

## Standards

Drop a file from `standards/` as `CLAUDE.md` in any project root to apply stack conventions. Compress with `/caveman:caveman-compress CLAUDE.md` to cut tokens.

Available: `spring-boot.md`, `go-microservice.md`, `cloud-functions.md`, `report-service.md`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `claude CLI not found` | Install + login to Claude CLI |
| `uvx not found` | `./install.sh` re-runs dep install |
| Push blocked, urgent | `PR_REVIEW_MODE=warn git push` |
| Hook not running | Check `git config --global core.hooksPath` points to `~/.git-hooks` |
| CRLF breaks scripts | `git add --renormalize .` (keep `.gitattributes`) |
| Statusline blank | Verify `python3` on PATH; test: `echo '{}' \| python3 statusline_tokens.py` |
