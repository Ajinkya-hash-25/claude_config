---
name: annotate-endpoint
description: Add Swagger @Operation + @ApiResponse annotations to a Spring Boot controller endpoint. Trigger on "/annotate-endpoint <MethodName>" or selecting endpoint lines. No @RequestBody/@Content/@Schema redundancy — Springfox infers from DTO.
---

Add minimal OpenAPI annotations to Spring Boot controller endpoint.
Arg: method name, or select lines then invoke.

## Steps

1. **Find endpoint** — Grep `src/main/java/**/*Controller.java` for method name; read signature + 3 surrounding lines
2. **Find DTO** — identify `@RequestBody DtoType`; Grep for `class DtoType`; read fields
3. **Add imports** if missing — `io.swagger.v3.oas.annotations.Operation` + `ApiResponse` after last import
4. **Write annotations** above `@PostMapping`/`@GetMapping`:
   ```java
   @Operation(summary = "<imperative phrase>", description = "<action, key fields, side effects>")
   @ApiResponse(responseCode = "200", description = "<what success means>")
   ```
5. **Verify** — re-read annotated lines; report method + summary used

## Rules

- No `@RequestBody`/`@Content`/`@Schema`/`@ExampleObject` — Swagger infers from Spring `@RequestBody`
- No error `@ApiResponse` unless asked
- `summary` max ~8 words imperative (e.g. "Delete entry from bank card whitelist")
