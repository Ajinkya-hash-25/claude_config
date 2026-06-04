---
name: statusline
description: Session token usage statusline for Claude Code. Displays input, cache hit, cache creation, output tokens. Use /statusline-setup to configure automatically.
---

Reads session JSONL from `~/.claude/projects/<slug>/<session_id>.jsonl`. Prints one line: `[in:18k hit:16.9M new:2k out:153k]`.

## Wire into settings

After install, `statusline_tokens.py` is at `~/.claude/skills/statusline/statusline_tokens.py`.

Add to `~/.claude/settings.json`:

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

Alt — `ccusage` (cost + burn rate, zero-config):

```json
{ "statusLine": { "type": "command", "command": "bunx ccusage statusline" } }
```
