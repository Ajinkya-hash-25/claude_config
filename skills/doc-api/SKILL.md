---
name: doc-api
description: Generate API reference markdown from Spring Boot controller. Trigger on "/doc-api <Controller>", "document API", "generate API docs". Reads annotations, produces curl + table format.
---

Controller class → ready-to-paste API reference markdown. No fluff.
`$ARGUMENTS` = controller class name or file path.

## Steps

1. **Locate controller**
   - Graph: `semantic_search_nodes_tool(query="<name> controller")`
   - Fallback: `rg --files | rg -i "<name>Controller"`
2. **Read file** — ranged read, extract:
   - Class-level `@RequestMapping` base path
   - Each method: HTTP verb + path (`@GetMapping`, `@PostMapping`, etc.)
   - `@PathVariable`, `@RequestParam`, `@RequestBody` params
   - Return type / response wrapper
   - `@Operation` / `@ApiResponse` Swagger annotations if present
3. **Infer** missing info from method names + DTOs (read DTO file if needed)
4. **Generate markdown** — fill template below

## Output Template

```markdown
# <EntityName> API

Base URL: `/api/v1/<resource>`

---

## Endpoints

### <HTTP_VERB> <path>

**Description:** <one line what it does>

**Request**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `field` | `String` | Yes | ... |

**Path Params** (if any)

| Param | Type | Description |
|-------|------|-------------|
| `id` | `Long` | Resource ID |

**Query Params** (if any)

| Param | Type | Default | Description |
|-------|------|---------|-------------|

**Example Request**

```bash
curl -X <VERB> "http://localhost:8080/api/v1/<resource>" \
  -H "Content-Type: application/json" \
  -d '{ "<field>": "<value>" }'
```

**Response**

| Field | Type | Description |
|-------|------|-------------|
| `id` | `Long` | ... |

**Status Codes**

| Code | Meaning |
|------|---------|
| `200` | Success |
| `400` | Validation error |
| `404` | Not found |

---
```

Repeat block per endpoint. End with `---`.

## Rules

- One H3 per endpoint method.
- No lorem ipsum. Infer real field names from DTO.
- If DTO has `@NotNull`/`@NotBlank` → Required = Yes.
- If return type is `CommonResponse<T>` → unwrap `T` for response table.
- curl uses `localhost:8080` as default host.
- Output only markdown — no preamble.
