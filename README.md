# lovestorage-server

Java 后端独立仓库。M1 基线采用 Java 21 + Spring Boot 4.1.1 + PostgreSQL + Flyway。

## 仓库职责

- 负责 Item / InventoryBatch / Category 等服务端领域逻辑与 REST API。
- `openapi/smart-expiry-v1.yaml` 是前后端 HTTP 契约真源。
- `shared/expiry-test-cases.json` 是 ArkTS / Java 保质期规则真源。
- 数据库 Schema 由 Flyway 管理。

## 目录

```text
src/
openapi/
shared/
scripts/
docs/
.github/workflows/
pom.xml
mvnw
docker-compose.yml
```

## 启动

```bash
docker compose up -d postgres
./mvnw test
./mvnw spring-boot:run
```

Windows：

```powershell
docker compose up -d postgres
mvnw.cmd test
mvnw.cmd spring-boot:run
```

健康检查：

```bash
curl http://localhost:8080/api/v1/health
```

## 契约优先

API 变更顺序：

1. 修改 `openapi/smart-expiry-v1.yaml`。
2. 评审兼容性与字段语义。
3. 修改 Java DTO / Controller / Service。
4. 更新测试。
5. 合并后通知前端同步 contract snapshot。

## 共享 expiry 规则

修改 `shared/expiry-test-cases.json` 后必须运行：

```bash
./mvnw test
```

Java `ExpiryServiceContractTest` 会直接读取该共享文件。前端通过 `sync_contracts.py` 获取同一份 JSON。

## 分支

- `main`：稳定可部署。
- `feature/<topic>`：功能开发。
- `fix/<topic>`：缺陷修复。
- API 契约稳定点可创建 tag：`contract-vX.Y.Z`。
