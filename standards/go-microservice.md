# Go Microservice — Claude Guide

Always respond in `/caveman` mode. Terse. No overexplain. Answer only asked.

---

## Stack

- Go 1.19+
- Standard `net/http` or chi/gin/echo router
- PostgreSQL via `database/sql` + `pgx` or `sqlx`
- Structured logging: `zap` or `slog` (Go 1.21+)
- Config: `os.Getenv` or `viper`

## Package Layout

```
<service>/
├── cmd/
│   └── server/
│       └── main.go       entry point, wire deps
├── internal/
│   ├── handler/          HTTP handlers (thin)
│   ├── service/          business logic interfaces + impls
│   ├── repository/       DB access layer
│   ├── model/            structs: domain, request, response
│   ├── middleware/        auth, logging, recovery
│   └── config/           config loading
├── pkg/                  exported shared utilities
├── migrations/           SQL migration files
├── go.mod
└── go.sum
```

## Architecture Rules

- **Layered**: Handler → Service → Repository. No skip.
- Handler = thin. Parse request, call service, write response. No business logic.
- Service = all logic. Transactions, orchestration, external calls.
- Repository = DB only. No business logic.
- Domain structs in `model/`. Request/Response DTOs separate from DB models.
- Use interfaces for service and repository — enables testing, mocking.

## Handler Standards

```go
func (h *ResourceHandler) Create(w http.ResponseWriter, r *http.Request) {
    var req model.CreateResourceRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        writeError(w, http.StatusBadRequest, "invalid body")
        return
    }
    result, err := h.svc.Create(r.Context(), req)
    if err != nil {
        writeError(w, http.StatusInternalServerError, err.Error())
        return
    }
    writeJSON(w, http.StatusCreated, result)
}
```

- Always pass `r.Context()` to service calls
- Decode → validate → call service → write response
- No business logic in handler

## Service Standards

- Define interface in same file or `service/<name>.go`
- Impl struct with injected dependencies (constructor injection)
- Always accept `context.Context` as first param
- Return `(result, error)` — never panic on expected errors
- Wrap errors: `fmt.Errorf("create resource: %w", err)`

## Repository Standards

- Interface in `repository/<name>.go`
- Use prepared statements / parameterized queries — never string concat
- Accept `ctx context.Context` always
- Return domain models, not raw SQL rows
- Transactions: pass `*sql.Tx` or use transaction wrapper

## Error Handling

- Check every error. No `_` for errors.
- Wrap with context: `fmt.Errorf("operation: %w", err)`
- Sentinel errors for domain errors: `var ErrNotFound = errors.New("not found")`
- `errors.Is` / `errors.As` for unwrapping — never string comparison
- No `panic` in business logic

## Logging

- Use `zap.Logger` or `slog.Logger` — no `log.Printf`
- Pass logger via context or constructor injection
- Structured fields: `logger.Info("event", zap.String("key", val))`
- Log at handler entry (request) and on errors
- Never log: passwords, tokens, PII, full request bodies

## Config

- All config from env vars (`os.Getenv`) or config file (`viper`)
- No hardcoded URLs, secrets, ports
- Fail fast at startup if required config missing

```go
dsn := os.Getenv("DATABASE_URL")
if dsn == "" {
    log.Fatal("DATABASE_URL required")
}
```

## Concurrency

- Always cancel context on timeout: `context.WithTimeout(ctx, 5*time.Second)`
- No goroutine leaks: use `errgroup` or `sync.WaitGroup` with done channel
- No `defer` inside loops — extract to function
- Mutex: always `defer mu.Unlock()` immediately after `mu.Lock()`

## Testing

- Table-driven tests: `[]struct{ name, input, want }`
- Mock interfaces via generated mocks (`mockery`) or manual stubs
- No live DB in unit tests — use interface mocks
- Integration tests in `_test.go` with `//go:build integration` tag

## Claude Workflow

1. Graph-first: `code-review-graph` MCP before Read/Grep
2. If graph empty/stale/timed out: fallback to `rg`, `rg --files`, then ranged reads
3. Reuse check: `code-reuse-finder` agent or local graph/rg search before writing new function
4. Scaffold: `go-scaffold` skill for new handlers/services
5. Test scenarios: `test-case-gen` skill

## Don'ts

- No `panic` in handlers or services
- No business logic in handlers
- No raw SQL string concatenation (SQL injection)
- No global mutable state
- No `os.Exit` except in `main.go`
- No ignored errors (`_ = someFunc()`) for non-trivial operations
