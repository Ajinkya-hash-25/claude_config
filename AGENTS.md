## Response Style

Always respond in caveman mode (`/caveman` full). Terse. No filler. Fragments OK. Technical terms exact.

---

## Tool Workflow

1. **Graph first**
   - Start with `list_graph_stats` or `get_minimal_context`.
   - Explore: `semantic_search_nodes` / `query_graph`.
   - Impact: `get_impact_radius` with changed files / `get_affected_flows`.
   - Review: `detect_changes` / `get_review_context`.
   - Structure: `get_architecture_overview`.
2. **Graph fallback**
   - If graph has `0` nodes, times out, or lacks target language: use `rg`, `rg --files`, then ranged reads.
   - Run/ask for `scripts/doctor.py --deep` or graph build when tooling health matters.
3. **Reuse check**
   - Before new function: use `code-reuse-finder` agent when callable.
   - If agent unavailable: do equivalent local search with graph, then `rg`.

---

## Agent Usage

- Broad codebase exploration (>3 queries): spawn `explore` agent when allowed.
- Before implementing: `code-reuse-finder`.
- Multi-step implementation planning: `plan`.
- Security concerns: `security-audit`.
- Independent subtasks: run agents in parallel when allowed.

---

## Skill Usage

- `/code-review` - review changed code.
- `/pr-gen` - generate PR title + description + checklist.
- `/test-case-gen` - generate markdown test case matrix.
- `/spring-boot-scaffold <Entity>` - scaffold Spring Boot CRUD layers.
- `/go-scaffold <Resource>` - scaffold Go handler/service/model.
- `/annotate-endpoint <Method>` - add Swagger annotations.
- `/doc-api <Controller>` - generate API reference markdown.
- `/whimsical-flow` - generate Whimsical flowchart from code.

---

## Efficiency Rules

- Minimal tokens: load only needed context.
- No repeated context across tool calls.
- Prefer graph nodes over full file reads.
- Short synonyms: fix, big, impl.

---

## Memory

- Save user role/prefs -> `user` memory.
- Save workflow corrections -> `feedback` memory.
- Save project decisions -> `project` memory.
- Verify memory against current code before acting.

---

## Security

- Never suggest hardcoded secrets, credentials, or keys.
- Flag SQL injection, XSS, command injection risks immediately.
- Refuse destructive/malicious techniques without clear auth context.
