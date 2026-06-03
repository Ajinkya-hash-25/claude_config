# Spring Boot — Claude Guide

Always respond in `/caveman` mode. Terse. No overexplain. Answer only asked.

---

## Stack

- Spring Boot `2.x+`, Java `8+`
- PostgreSQL + Spring Data JPA + `JdbcTemplate` (native queries)
- Lombok, Swagger/Springfox or SpringDoc, RabbitMQ (optional)

## Package Layout

```
com.<org>.<service>
├── controller/   REST endpoints only
├── service/      interfaces
│   └── impl/     @Service business logic
├── repository/   JpaRepository + @Query native
├── entity/       JPA entities (DB mapped)
├── dto/          request/response DTOs
├── enums/        enum constants
└── config/       Security, RabbitMQ, Swagger, AppConfig
```

## Architecture Rules

- **Layered**: Controller → Service (`impl`) → Repository. No skip.
- Controller = thin. No business logic. Only routing, validation, delegate.
- Service `impl` = all logic. Transactions, orchestration, external calls.
- Repository = DB only. `@Query(nativeQuery = true)` for complex SQL; named params via `@Param`.
- Never expose `entity` from controller. Map to DTO.
- Entity → `entity/`, suffix `Entity`.
- DTO → `dto/`, suffix `Dto` / `Request` / `Response`.

## Controller Standards

- `@RestController` + `@RequestMapping("resource_name")` on class
- Return uniform response wrapper (e.g. `CommonResponse` or `ResponseEntity<?>`)
- Entry/exit logging on every handler
- `throws Exception` allowed — global handler catches

```java
@GetMapping("/ping")
public CommonResponse ping(HttpServletRequest request) throws Exception {
    log.info("ping entry");
    CommonResponse res = new CommonResponse(HttpStatus.OK.value(), "SUCCESS", service.ping());
    log.info("ping exit");
    return res;
}
```

## Service Standards

- Interface in `service/`, impl in `service/impl/` suffix `ServiceImpl`
- `@Service` on impl, `@Autowired` field injection (match project convention)
- `Logger log = LoggerFactory.getLogger(X.class)` — no `System.out`
- Small methods, single responsibility. Extract helpers for reuse.
- Check for existing services before creating new ones.

## Repository Standards

- Extend `JpaRepository<Entity, IdType>`
- `@Transactional` at interface level when mutations present
- Native SQL → `@Query(value="...", nativeQuery=true)`; cast timestamps: `cast(:startDate as timestamp)`
- Mutations → `@Modifying` + `@Transactional`
- Complex joins → `JdbcTemplate` + `BeanPropertyRowMapper`

## DTO Standards

- Lombok `@Data` / `@Getter @Setter @NoArgsConstructor @AllArgsConstructor`
- PascalCase class names, suffix matches role (`Dto`, `Request`, `Response`)
- No JPA annotations in DTO. No business logic.

## Coding Practices

- No duplicate logic — reuse shared utils and existing services
- Keep methods under ~50 lines when possible
- `@Value("${prop}")` for config — never hardcode URLs/keys
- External HTTP → `RestTemplate` with `HttpEntity` + `HttpHeaders`
- JSON → Jackson `ObjectMapper`; CSV → OpenCSV; Excel → Apache POI
- Dates → prefer `java.time` (`LocalDateTime`, `DateTimeFormatter`)
- Never commit secrets. Use `.gitignore` for `application.properties` secrets.

## Logging

- SLF4J `LoggerFactory.getLogger(Class.class)`
- `log.info` on entry/exit of service methods
- `log.error("msg", e)` — pass exception object, not `e.getMessage()`
- Never log passwords, tokens, PII

## Claude Workflow

1. Graph-first: `code-review-graph` MCP before Read/Grep
2. If graph empty/stale/timed out: fallback to `rg`, `rg --files`, then ranged reads
3. Reuse check: `code-reuse-finder` agent or local graph/rg search before writing new function
4. Test scenarios: `test-case-gen` skill
5. Scaffold: `spring-boot-scaffold` skill for new CRUD endpoints

## Don'ts

- No business logic in controller
- No entity leakage to API
- No hardcoded config/secrets
- No `System.out.println` — use logger
- No skipping service layer (controller → repo direct = reject)
