---
name: go-scaffold
description: Generate Go microservice handler/service/model skeleton from service or resource name. Follows org Go conventions. Trigger on "/go-scaffold", "scaffold Go handler", "create Go service for <name>", "generate Go <resource>".
---

Resource name -> Go handler + service + model skeleton. Scaffold only. No business logic.

## Steps

1. Resolve name: PascalCase as-is; snake_case/camelCase -> PascalCase.
2. Detect graph-first, fallback Grep:
   - `go.mod` module name
   - `internal/` vs `pkg/` layout
   - Router style from existing handler: stdlib/chi/gin/echo
   - Service interface+impl pattern from existing service
3. Generate 3 files:
   - `model/<resource>.go` - domain/request/response structs, fields as TODO comments
   - `service/<resource>.go` - interface, unexported impl, constructor, compile-safe stubs
   - `handler/<resource>.go` - handler struct, constructor, Create/GetByID/List endpoints, detected router style
4. Report files created + wire-up reminder.

## Org Conventions

- `context.Context` first arg on all service methods.
- All errors returned. Never swallowed. No `log.Fatal` in handlers.
- Constructor injection. No global state.
- `json.NewDecoder/Encoder` for HTTP body. Not `ioutil.ReadAll`.
- Never log tokens, passwords, PII.
- Service stub methods must compile and contain no business logic:

```go
return zeroValue, errors.New("TODO: implement")
```

- Use `return errors.New("TODO: implement")` for error-only returns.
- Add `errors` import when stub methods return TODO errors.
