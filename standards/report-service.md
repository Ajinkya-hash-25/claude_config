# BnxtReportService — Claude Guide

Always respond in `/caveman` mode. Terse. No overexplain. Answer only asked.

---

## Stack

- Spring Boot `2.5.6`, Java `1.8`
- Postgres + Spring Data JPA + `JdbcTemplate` (native queries)
- Lombok, Springfox Swagger `3.0.0`, OpenCSV, Firebase Admin, RabbitMQ
- Shared lib: `com.finovate.bnxt.cm.BnxtCommonModule` (reuse `CommonUtil`, `CommonResponse`)

## Package Layout

```
com.finovate.bharatnxt.rs
├── controller/   REST endpoints only
├── service/      interfaces
│   └── impl/     @Service business logic
├── repository/   JpaRepository + @Query native
├── entity/       JPA entities (DB mapped)
├── dto/          request/response DTOs
├── enums/        enum constants
└── config/       RabbitMq, Swagger, AppConfiguration
```

## Architecture Rules

- **Layered**: Controller → Service (`impl`) → Repository. No skip.
- Controller = thin. No business logic. Only `@RequestMapping`, validation, delegate.
- Service `impl` = all logic. Transactions, orchestration, external calls.
- Repository = DB only. Use `@Query(nativeQuery = true)` for complex SQL; named params via `@Param`.
- Never expose `entity` from controller. Map to DTO.
- Entity class → `entity/`, suffix `Entity`.
- DTO class → `dto/`, suffix `Dto` / `Request` / `Response`.

## Controller Standards

- `@RestController` + `@RequestMapping("resource_name")` on class
- Return `CommonResponse` from `BnxtCommonModule` (uniform shape)
- Wrap every handler with `CommonUtil.entryLog("method")` / `CommonUtil.exitLog("method")`
- `HttpStatus.OK.value()` + `CommonUtil.SUCCESS` for success responses
- `throws Exception` allowed — global handler catches

```java
@GetMapping("/ping")
public CommonResponse ping(HttpServletRequest request) throws Exception {
    CommonUtil.entryLog("ping");
    CommonResponse res = new CommonResponse(HttpStatus.OK.value(),
        CommonUtil.SUCCESS, adminDashboardService.testingMethod());
    CommonUtil.exitLog("ping");
    return res;
}
```

## Service Standards

- Interface in `service/`, impl in `service/impl/` suffix `ServiceImpl`
- `@Service` on impl, `@Autowired` field injection (repo convention)
- `Logger log = LoggerFactory.getLogger(X.class)` — no `System.out`
- Small methods, single responsibility. Extract helpers for reuse.
- Reuse existing services before writing new ones (`AdminDashboardService`, `DashboardService`, `ReportService`, `DisputeDashboardService`, `MoengageService`)

## Repository Standards

- Extend `JpaRepository<Entity, IdType>`
- `@Transactional` at interface level when mutations present
- Native SQL → `@Query(value="...", nativeQuery=true)`; cast timestamps: `cast(:startDate as timestamp)`
- Mutations → `@Modifying` + `@Transactional`
- Complex joins → `CrossTableQueryRepo` via `JdbcTemplate` + `BeanPropertyRowMapper`

## DTO Standards

- Lombok `@Data` / `@Getter @Setter @NoArgsConstructor @AllArgsConstructor`
- PascalCase class names, suffix matches role (`Dto`, `Request`, `Response`)
- No JPA annotations in DTO. No business logic.

## Coding Practices

- No duplicate logic → reuse `CommonUtil` and shared services
- Keep methods under ~50 lines when possible
- Use `@Value("${prop}")` for config — never hardcode URLs/keys
- External HTTP → `RestTemplate` with `HttpEntity` + `HttpHeaders`
- JSON → Jackson `ObjectMapper`; CSV → OpenCSV `CSVWriter`
- Excel → Apache POI `WorkbookFactory`
- Dates → `SimpleDateFormat` (legacy) or `DateTimeFormatter` (new code prefer `java.time`)
- Never commit secrets. `application.properties` + firebase JSONs are `.gitignore`d

## Logging

- SLF4J `LoggerFactory.getLogger(Class.class)`
- `log.info` entry/exit via `CommonUtil.entryLog` / `exitLog`
- `log.error("msg", e)` — pass exception object, not `e.getMessage()`

## Claude Workflow

1. Graph-first: use `code-review-graph` MCP (`semantic_search_nodes`, `get_impact_radius`, `detect_changes`) BEFORE Read/Grep
2. Reuse check: `code-reuse-finder` agent before writing new function
3. Test scenarios: `test-case-gen` agent
4. Keep context minimal. Prefer graph nodes over full file reads.

## Don'ts

- No business logic in controller
- No entity leakage to API
- No hardcoded config/secrets
- No `System.out.println` — use logger
- No new util classes if `CommonUtil` covers it
- No skipping service layer (controller → repo direct = reject)
