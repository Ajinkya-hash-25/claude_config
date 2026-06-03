---
name: pr-gen
description: Generate PR title, description, and checklist from git diff + branch context. Trigger on "/pr-gen", "generate PR", "write PR description", "create PR". Works for Java/Spring Boot, Go, Cloud Functions.
---

Git diff → ready-to-paste PR description. No fluff.
Optional args: base branch (default: upstream, `origin/main`, `origin/master`, then `HEAD~1`); `$ARGUMENTS` = Jira ticket / feature name.

## Steps

1. **Get context**
   - `Bash(git rev-parse --abbrev-ref HEAD)` → branch name
   - `Bash(git log <base>...HEAD --oneline)` → commit list
   - `Bash(git diff <base>...HEAD --stat)` → changed files summary
   - `Bash(git diff <base>...HEAD)` -> capped diff (500 lines max; summarize by file if larger)
2. **Classify change type** from diff + branch name:
   - `feat` — new feature or endpoint
   - `fix` — bug fix
   - `refactor` — restructure, no behavior change
   - `chore` — deps, config, build
   - `docs` — documentation only
   - `test` — tests only
   - `perf` — performance improvement
3. **Extract key changes** — what was added/changed/removed, grouped by file/layer
4. **Generate PR** — fill template below

## Output Template

```markdown
## Summary

<2-4 bullet points. What changed and why. No "this PR" prefix.>

## Changes

<Grouped by layer/service. E.g.:>
**Controller**
- Added `POST /resource` endpoint

**Service**
- Implemented `createResource()` with validation

**DB / Migration**
- Added `resource` table with indexes

## Test Plan

- [ ] <manual test step 1>
- [ ] <manual test step 2>
- [ ] Unit tests pass: `<test command>`
- [ ] No regressions in `<related area>`

## Related

<!-- Jira: PROJ-XXX | PR: #xxx | Ticket: <link> -->
```

## PR Title Format

```
<type>(<scope>): <short imperative description>
```

Examples:
- `feat(payments): add retry logic for failed transactions`
- `fix(auth): null check before token expiry validation`
- `refactor(reports): extract CSV generation to service layer`

## Rules

- Title max 72 chars
- Summary bullets: what + why, not how
- Test plan: concrete steps, not "test the feature"
- If Jira ticket in branch name (e.g. `PROJ-123-feature`) → auto-extract to Related
- If diff > 500 lines: summarize by file, don't dump full diff
- No "This PR does X" — start bullets with verb ("Add", "Fix", "Remove")
- Output only the PR markdown — no preamble, no explanation
