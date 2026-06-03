---
name: code-review
description: Structured code review for Java/Spring Boot, Go microservices, Cloud Functions, SQL, YAML, config files. Trigger on "review this", "review PR", "/code-review". Graph-first, terse output.
---

Review changed code. Flag bugs, risks, nits. Findings first.
Optional arg: base branch (default: upstream, `origin/main`, `origin/master`, then `HEAD~1`)

## Steps

1. Get diff scope
   - Graph: `detect_changes_tool(base=<base>)`
   - Raw diff: `git diff <base>...HEAD`
2. Impact check
   - `get_impact_radius_tool(changed_files=[...], depth=1)`
   - `get_affected_flows_tool(changed_files=[...])`
3. If graph unavailable
   - Continue with diff-only review
   - Use `rg`/ranged reads only for needed context
4. Review changed lines only
5. Verdict last line:
   - `APPROVE`
   - `REQUEST CHANGES - <one line why>`

## Output Format

```text
<file>:L<n>: bug: <problem>. <fix>.
<file>:L<n>: risk: <problem>. <fix>.
<file>:L<n>: nit: <problem>. <fix>.

APPROVE
```

## Checks

- Java: null checks, transactions, DTO boundaries, logger, hardcoded config, SQL injection.
- Go: unchecked errors, goroutine leaks, context propagation, nil deref, defer in loop.
- Cloud Functions: timeout, idempotency, cold start, double-send, secrets in logs.
- SQL/YAML/config: secrets, unsafe query concat, missing required fields.

## Rules

- Exact `file:L<line>` references.
- No comments on untouched code.
- No hedging. Use `q:` if unsure.
- Skip test/mock files unless critical.
- Max 20 findings.
