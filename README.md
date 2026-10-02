# Smart Expiry M1 Baseline

智能保质期管理项目的 M1 可运行基线。仓库按 **monorepo** 组织，但客户端、后端和契约目录边界清晰，可随时拆分为双仓/多仓。

## 目录

```text
smart-expiry-m1/
├── harmonyos/                  # HarmonyOS ArkTS / ArkUI / Stage 模型
├── backend/                    # Java 21 + Spring Boot 4.1.1
├── openapi/                    # API source of truth
├── shared/                     # 跨端共享测试契约
├── scripts/                    # 生成/校验共享 fixture
├── docs/                       # 技术设计与协作说明
├── docker-compose.yml          # 本地 PostgreSQL
└── Makefile                    # 常用命令
```

## M1 已落地

- HarmonyOS Stage 工程骨架，可用 DevEco Studio 直接导入。
- ArkTS `ExpiryService`，与 Java 使用同一组保质期规则测试数据。
- ArkData RDB 本地 `item` 表与最小 CRUD Repository。
- Spring Boot 4.1.1 / Java 21 后端。
- Item + InventoryBatch 最小 CRUD API。
- PostgreSQL + Flyway V1 初始化迁移。
- OpenAPI 3.1 契约文件。
- `/shared/expiry-test-cases.json` 作为跨端保质期规则真源。
- Java 自动读取根目录共享 fixture；HarmonyOS fixture 由脚本生成。
- Docker Compose 本地 PostgreSQL。

## 1. 启动后端

前置：Docker、JDK 21。Maven 可不安装，仓库提供 `backend/mvnw`。

```bash
docker compose up -d postgres
cd backend
./mvnw spring-boot:run
```

Windows：

```powershell
docker compose up -d postgres
cd backend
mvnw.cmd spring-boot:run
```

后端默认：`http://localhost:8080`

健康检查：

```bash
curl http://localhost:8080/api/v1/health
```

## 2. 运行后端测试

```bash
cd backend
./mvnw test
```

`ExpiryServiceContractTest` 会直接读取 `../shared/expiry-test-cases.json`，避免 Java 端维护副本。

## 3. 启动 HarmonyOS 客户端

1. 使用支持 HarmonyOS 6.0 / API 20 的 DevEco Studio 打开 `harmonyos/`。
2. 首次打开后执行项目同步；如本机 SDK/Hvigor 版本更高，使用 IDE 的 Upgrade Dependencies。
3. 配置自动签名。
4. 运行 `entry` 到手机/模拟器。

客户端 M1 默认使用本地 ArkData，因此即使后端未启动也能运行；远端 API Client 已保留在 `data/remote`。

> HarmonyOS 的 SDK 与 Hvigor 由 DevEco Studio 管理。本仓库固定业务代码与工程结构，不提交本机 SDK/签名文件。

## 4. 修改保质期规则时

唯一真源：

```text
shared/expiry-test-cases.json
```

更新后执行：

```bash
python3 scripts/sync_shared_fixtures.py
python3 scripts/verify_shared_fixtures.py
```

Java 测试直接读取共享 JSON；ArkTS 测试使用脚本生成的 `ExpiryFixtures.ets`。

## 5. OpenAPI

契约：

```text
openapi/smart-expiry-v1.yaml
```

M1 规则：**先改 OpenAPI，再改实现**。接口兼容性要求见 `docs/CONTRIBUTING.md`。

## 6. 双仓拆分建议

当前 monorepo 可拆为：

- `smart-expiry-app` ← `harmonyos/`
- `smart-expiry-server` ← `backend/`
- `smart-expiry-contract` ← `openapi/ + shared/`

拆仓时推荐将 contract 仓作为 Git submodule、CI 拉取依赖，或发布为独立制品。不要复制后各自维护。

## 7. M1 Definition of Done

- `docker compose up -d postgres` 可启动 PostgreSQL。
- `backend/mvnw test` 全部通过。
- `backend/mvnw spring-boot:run` 可启动，Flyway 自动建表。
- `/api/v1/health` 返回成功。
- Item 可创建、列表、详情、修改、软删除。
- HarmonyOS 项目可被 DevEco Studio 导入并运行。
- ArkTS 本地 Repository 支持创建、查询、更新、软删除。
- Java / ArkTS 对共享 expiry fixture 的规则实现一致。
