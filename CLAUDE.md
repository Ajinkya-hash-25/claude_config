## Code Context (MANDATORY)

Use code-review-graph BEFORE any file reads.

Priority:
- Explore → semantic_search_nodes / query_graph
- Impact → get_impact_radius / get_affected_flows
- Review → detect_changes / get_review_context
- Structure → get_architecture_overview

Fallback to Grep/Read ONLY if graph is insufficient.

## Spring Boot Code Standards

- Follow layered architecture: Controller → Service → Repository
- Keep business logic ONLY in Service layer
- Use DTOs, avoid exposing entities
- Write small, single-responsibility methods
- Avoid duplicate logic (reuse services/utilities)


## Efficiency Rules

- Minimize tokens: load minimal files/notes
- Prefer graph + vault over code scanning
- Avoid repeated context
- Be concise but complete
- Use the caveman inorder to give response everytime.