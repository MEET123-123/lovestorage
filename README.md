> 当前本地候选版：0.4.0。新增账号隔离、完整快照备份/恢复、规则识别、个人资料和仅限本地 profile 的手机号验证码调试。短信调试不会发送短信；华为账号认证尚未配置。启动与使用见 [本地候选版说明](docs/LOCAL_CANDIDATE.md)。除健康检查、登录能力查询和登录路由外，API 需要 Bearer 令牌。

# lovestorage-server

Docker 运行后端 + PostgreSQL、查看数据和 IDE 断点调试步骤见 [Docker 调试指南](docs/DOCKER_DEBUG.md)。

IDEA 数据库连接、Java 断点和 Postman 集合导入步骤见 [IDEA / Postman 联调指南](docs/IDEA_POSTMAN.md)。可导入的测试集合和环境文件位于 `postman/`。

## Windows 本地运行（2026-10-03 已验证）

```powershell
.\scripts\build.ps1
.\scripts\run.ps1
```

默认使用 `local` profile，H2 文件数据库保存到 `data/`，无需 Docker，重启保留数据。
`scripts/run.ps1 -Profile default` 使用下文的 PostgreSQL 配置。
前端工程为同级 `../append/harmonyos`。当前已支持客户端幂等创建 ID、生命周期状态更新、API 20 的 PUT 更新兼容入口。
详细验证记录和已知限制见 `docs/VALIDATION.md`，工作区完整操作步骤见 `../README.md`。

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

版本设计、实际实现边界与历史变更见 [版本记录索引](docs/ChangeLog/README.md) 和 [工程变更记录](docs/ChangeLog/CHANGELOG.md)。
