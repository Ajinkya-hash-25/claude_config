---
name: Standup
description: Summarize today's git commits and open PRs into a standup blurb
---

Generate a standup update from today's git activity.

## Steps

1. Run `git log --since="yesterday" --oneline --author="$(git config user.name)"` to get today's commits.
2. If `gh` is available, run `gh pr list --author="@me" --state=open` for open PRs.
3. Summarize into standup format.

## Output format

```
Yesterday:
- <what was done, inferred from commit messages>

Today:
- <in-progress PRs or next logical step from last commit>

Blockers:
- None (or list if commits mention fix/workaround for external dep)
```

## Rules

- Caveman mode. Fragments OK. No filler.
- Group related commits into one line — don't list every commit verbatim.
- Infer intent from commit message, don't just repeat it.
- If no commits today, say so. Don't fabricate activity.
- Keep entire output under 10 lines.
