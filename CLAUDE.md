# CLAUDE.md

Org-wide Claude Code guidelines. Merge with project-specific `CLAUDE.md` as needed.

---

## 1. Response Style

Caveman mode active. Start `/caveman full` each session.

- Terse. Fragments OK. No filler (just/basically/actually/of course).
- Technical terms exact. Code blocks unchanged.
- Drop: "I'll help you", "Great question", "Sure!".
- Pattern: `[thing] [action] [reason]. [next step].`

---

## 2. Think Before Coding

Don't assume. Surface tradeoffs. Ask before implementing ambiguous tasks.

- State assumptions explicitly.
- If multiple interpretations: present all, don't pick silently.
- If simpler path exists: say so.
- Unclear requirement → stop, name confusion, ask.

---

## 3. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No error handling for impossible scenarios.
- 200 lines achievable in 50 → rewrite.

---

## 4. Surgical Changes

Touch only what you must.

- Don't "improve" adjacent code, comments, formatting.
- Don't refactor things not broken.
- Match existing style.
- Unrelated dead code: mention, don't delete.
- Every changed line traces to user's request.

---

## 5. Tool Workflow — Graph First

**Step 1 — Orient:**
```
list_graph_stats          # node count, languages — confirms graph alive
get_minimal_context       # entry points, key files
get_architecture_overview # high-level structure
```

**Step 2 — Explore:**
```
semantic_search_nodes <query>   # find relevant symbols
query_graph <natural language>  # broader cross-cutting query
```

**Step 3 — Impact (before edit):**
```
get_impact_radius <files>   # what breaks if these change
get_affected_flows <symbol> # trace call/data flows
```

**Step 4 — Review (after edit):**
```
detect_changes        # diff vs graph state
get_review_context    # risk summary for changed files
```

**Fallback** (graph 0 nodes / timeout / wrong language):
```
rg --files                     # enumerate
rg <symbol>                    # locate
read file:start_line-end_line  # ranged read, not full file
```

---

## 6. Reuse Before New Code

Before writing new function/module:
1. `semantic_search_nodes <what you need>`
2. `query_graph "existing utils for X"`
3. Only if nothing found: implement.

---

## 7. Agent Usage

| When | Agent |
|---|---|
| Broad exploration (>3 queries) | `explore` |
| Pre-impl reuse check | `code-reuse-finder` |
| Multi-step plan | `plan` |
| Security concern | `security-audit` |
| Independent subtasks | parallel agents |

Spawn parallel when tasks don't share state.

---

## 8. Skill Usage

| Skill | When |
|---|---|
| `/code-review` | review changed code |
| `/pr-gen` | PR title + description + checklist |
| `/test-case-gen` | markdown test case matrix |
| `/spring-boot-scaffold <Entity>` | scaffold CRUD layers |
| `/go-scaffold <Resource>` | scaffold handler/service/model |
| `/annotate-endpoint <Method>` | add Swagger annotations |
| `/doc-api <Controller>` | generate API reference |
| `/whimsical-flow` | flowchart from code |

---

## 9. Token Discipline

- Load only needed context per tool call.
- No repeated context across calls.
- Prefer graph node reads over full file reads.
- Ranged reads (`file:10-80`) over full file when location known.
- One tool call per data need — no redundant fetches.

---

## 10. Goal-Driven Execution

Transform tasks into verifiable goals:

```
"Fix bug" → write test that reproduces it, then make it pass.
"Add feature" → write tests for expected behavior, then impl.
"Refactor" → tests pass before and after.
```

Multi-step tasks: state brief plan first:
```
1. [step] → verify: [check]
2. [step] → verify: [check]
```

---

## 11. Memory

- User role/prefs → `user` memory.
- Workflow corrections → `feedback` memory.
- Project decisions → `project` memory.
- Verify memory against current code before acting. Stale memory loses to live code.

---

## 12. Security

- Never hardcode secrets, credentials, keys.
- Flag immediately: SQL injection, XSS, command injection.
- Refuse destructive/malicious techniques without clear auth context.
- `curl | bash` patterns: use tmpfile + inspect pattern instead.
