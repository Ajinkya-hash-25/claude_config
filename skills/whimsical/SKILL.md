---
name: whimsical-flow
description: Generate Whimsical flow diagram from code. Trigger on "flow diagram", "flowchart", "/whimsical-flow", or code range + visualization ask. Token-lean — caveman mode + code-review-graph first.
---

Code → Whimsical flowchart. Min tokens.

## Steps

1. **Locate symbol via graph** (no file read yet):
   - `mcp__code-review-graph__semantic_search_nodes_tool` or `query_graph_tool` for function name.
   - `mcp__code-review-graph__get_minimal_context_tool` → get control flow + callees.
   - Only if graph misses → `Read` ranged (`offset`+`limit`). Never full file.
2. **Extract**: branches, throws, DB/IO, return. Skip trivial assigns.
3. **Board**:
   - User gave URL/id → use it.
   - Else `mcp__whimsical-desktop__board_create` title `<fn> Flow`.
4. **Render**: `mcp__whimsical-desktop__flowchart_create` with mermaid.
5. **Reply**: board URL + one-line. No mermaid dump unless asked.

## Mermaid rules

- `graph TD`
- Shapes: `([start/end])` `{decision}` `[action]` `[(db)]`
- Colors: start `#2C88D9`, end `#1AAE9F`, throw/error `#D3455B`
- Merge same error branches → one node
- Labels <40 chars
- Single connected graph (tool rejects split)

## Token budget

- 1-2 graph calls (no Read if graph enough)
- 1 board_create (skip if URL given)
- 1 flowchart_create
- Final: URL + 1 line

## Skip

- Full file reads
- Per-branch narration
- Re-pasting mermaid
- Multiple diagrams/call
- Pleasantries
