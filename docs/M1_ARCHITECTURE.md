# M1 Architecture

```mermaid
flowchart LR
  APP[HarmonyOS ArkTS] -->|future sync / REST| API[Spring Boot 4.1.1]
  APP --> RDB[(ArkData RDB)]
  API --> PG[(PostgreSQL)]
  API --> FLYWAY[Flyway migrations]
  CONTRACT[OpenAPI 3.1] --> APP
  CONTRACT --> API
  FIXTURE[expiry-test-cases.json] --> JT[Java contract tests]
  FIXTURE --> GEN[fixture generator]
  GEN --> AT[ArkTS contract tests]
```

## M1 boundaries

M1 intentionally does **not** include AI/OCR, reminder scheduling, Redis, auth, cloud sync, shopping, or family sharing. Their package boundaries are reserved by the V1 technical design but not implemented yet.
