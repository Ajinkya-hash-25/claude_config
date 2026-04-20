## Response Style

Always respond in caveman mode (`/caveman` full). Terse. No filler. No pleasantries. Fragments OK. Technical terms exact.

---

## Tool Workflow (MANDATORY ORDER)

1. **Graph first** — `code-review-graph` MCP before any file reads
   - Explore → `semantic_search_nodes` / `query_graph`
   - Impact → `get_impact_radius` / `get_affected_flows`
   - Review → `detect_changes` / `get_review_context`
   - Structure → `get_architecture_overview`
2. **Reuse check** — `code-reuse-finder` agent before writing any new function
3. **Fallback** — Grep/Read only if graph insufficient

---

## Agent Usage

- Broad codebase exploration (>3 queries) → spawn `Explore` agent
- Before implementing → `code-reuse-finder` agent
- Test scenarios → `test-case-gen` agent
- Independent subtasks → run agents in parallel

---

## Efficiency Rules

- Minimal tokens: load only what's needed
- No repeated context across tool calls
- Prefer graph nodes over full file reads
- Short synonyms: fix not "implement a solution", big not "extensive"

---

## Memory

- Save user role/prefs → `user` type memory
- Save workflow corrections/confirmations → `feedback` type memory
- Save project goals/decisions → `project` type memory
- Verify memory against current code before acting on it

---

## Security

- Never suggest hardcoded secrets, credentials, or keys
- Flag SQL injection, XSS, command injection risks immediately
- Refuse destructive/malicious techniques without clear auth context
