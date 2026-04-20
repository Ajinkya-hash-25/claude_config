# Statusline Setup — Claude Code

Custom statusline show token usage per session. Format:

```
[in:18k hit:16.9M new:2k out:153k]
```

- `in` → input tokens
- `hit` → cache read tokens
- `new` → cache creation tokens
- `out` → output tokens

---

## Prereq

- Claude Code CLI installed
- Python 3.9+ on `PATH`
- Windows → PowerShell (script uses it). Mac/Linux → swap for `bash`.

---

## Steps

### 1. Drop script

Path: `C:/Users/Admin/.claude/scripts/statusline_tokens.py`

Reads session JSONL from `~/.claude/projects/<slug>/<session_id>.jsonl`. Sums `usage` fields. Prints one line.

Full script at `C:/Users/Admin/.claude/scripts/statusline_tokens.py` in this repo setup.

### 2. Wire into settings

Edit `~/.claude/settings.json`. Add:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -NonInteractive -Command \"& python 'C:/Users/Admin/.claude/scripts/statusline_tokens.py'\""
  }
}
```

Mac/Linux variant:

```json
{
  "statusLine": {
    "type": "command",
    "command": "python3 ~/.claude/scripts/statusline_tokens.py"
  }
}
```

### 3. Reload

Restart Claude Code session. Statusline show bottom of UI.

---

## How it work

1. Claude Code invoke `command` each prompt cycle.
2. Pipes session JSON (`session_id`, `cwd`, `context_window`) to stdin.
3. Script locate JSONL, sum `usage` blocks, emit compact line.
4. Empty line at session start (no tokens yet).

---

## Troubleshoot

| Problem | Fix |
|---------|-----|
| Statusline blank | Check `python` on PATH. Run script manual with empty stdin. |
| `[in:0 out:0]` | JSONL path wrong. Verify `~/.claude/projects/` slug match cwd. |
| Stale numbers | Restart session — statusline refresh only per prompt. |
| PowerShell error | Use forward slashes in path. Quote path with `'...'`. |

Manual test:

```powershell
echo '{"session_id":"test","cwd":"C:/tmp"}' | python C:/Users/Admin/.claude/scripts/statusline_tokens.py
```

---

## Alt: ccusage statusline

`ccusage` = npm CLI. Show live session cost, token burn, block/daily spend. Zero-config.

### Install

Global (optional — `bunx`/`npx` work without install):

```bash
npm i -g ccusage
# or
bun add -g ccusage
```

Check:

```bash
ccusage --version
ccusage statusline --help
```

### Wire into settings

Edit `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bunx ccusage statusline",
    "padding": 0
  }
}
```

`npx`/global variants:

```json
{ "statusLine": { "type": "command", "command": "npx ccusage statusline" } }
{ "statusLine": { "type": "command", "command": "ccusage statusline" } }
```

Windows PowerShell wrap:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -Command \"bunx ccusage statusline\""
  }
}
```

### Output

```
🤖 Opus | 💰 $0.34 session / $12.10 today / $8.20 block (2h 15m left) | 🔥 $2.10/hr
```

- session cost
- today total
- 5hr block spend + time left
- burn rate

### Offline / fast mode

```bash
bunx ccusage statusline --offline     # skip pricing fetch
bunx ccusage statusline --visual-burn-rate emoji
```

### Troubleshoot

| Problem | Fix |
|---------|-----|
| `command not found` | Install node/bun. Use full path to `bunx`/`npx`. |
| Slow statusline | Add `--offline` flag. ccusage cache pricing. |
| No cost shown | Session fresh — need ≥1 turn. |
| Windows hang | Wrap in `powershell -NoProfile -Command`. |

Reload: restart Claude Code session.

---

## Customize

Edit `statusline_tokens.py`:

- `fmt()` → change number format
- `parts.append(...)` → add/remove fields
- Add git branch, model name, cost estimate etc.

Alt: use `/statusline` skill to let Claude configure for you.
