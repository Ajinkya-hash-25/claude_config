---
name: spring-boot-scaffold
description: Generate Spring Boot controller/service/repo/DTO/entity skeleton from entity name or DB table. Follows org layered architecture. Trigger on "/spring-boot-scaffold", "scaffold endpoint", "create CRUD for <entity>", "generate Spring Boot <entity>".
---

Entity name -> full Spring Boot CRUD skeleton. Scaffold only. No business logic.

## Steps

1. Resolve name: PascalCase as-is; snake_case -> PascalCase.
2. Detect graph-first, fallback Grep:
   - Root package from `@SpringBootApplication` or any `@RestController`
   - ID type + `@GeneratedValue` strategy from existing entity
   - Response wrapper: look for `CommonResponse` + `CommonUtil` usage
   - Injection style: `@Autowired` field vs constructor
3. Generate 6 files:
   - `entity/<EntityName>Entity.java` - `@Entity @Table @Data`, id + timestamps, fields as TODO comments
   - `repository/<EntityName>Repository.java` - `JpaRepository<Entity, Long>`
   - `service/<EntityName>Service.java` - interface: create/getById/getAll/update/delete
   - `service/impl/<EntityName>ServiceImpl.java` - `@Service`, logger, detected injection style, compile-safe stubs
   - `dto/<EntityName>Request.java` + `dto/<EntityName>Response.java` - Lombok DTOs, fields as TODO comments
   - `controller/<EntityName>Controller.java` - REST endpoints, service delegation, detected response wrapper
4. Report files created + wire-up reminder.

## Org Conventions

- `CommonResponse` / `CommonUtil`: use if found; else `ResponseEntity<?>`.
- Match project injection style. Default to constructor injection if no local pattern exists.
- SLF4J logger: `LoggerFactory.getLogger(Impl.class)`. No `System.out`.
- `@Value` placeholder comment for any config. Never hardcode.
- `entity_path` = lowercase plural of entity name.
- Service impl methods must compile and contain no business logic:

```java
throw new UnsupportedOperationException("TODO: implement");
```

- Controller methods may delegate to service; service stub throws until implemented.
