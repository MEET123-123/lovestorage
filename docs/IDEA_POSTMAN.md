> 0.3.0：先注册/登录取得 Bearer 令牌，再执行分类和库存接口。使用更新后的 Postman 集合；新版独立联调库为 smart_expiry_candidate，端口 18081。详细步骤见 [本地候选版](LOCAL_CANDIDATE.md)。下列 smart_expiry 配置仍适用于原 Docker 开发库。

# IDEA 与 Postman 本地联调

## 1. 启动容器

在 PowerShell 执行：

```powershell
cd D:\Src\lovestorage
docker compose --profile server up -d
docker compose --profile server ps
Invoke-RestMethod http://localhost:18080/api/v1/health
```

PostgreSQL 和 backend 均需运行。新版 health 会查询数据库，连接失败返回 503。

## 2. IDEA 连接数据库

打开 View → Tool Windows → Database，点击 + → Data Source → PostgreSQL。
填写：

| 参数 | 值 |
|---|---|
| Host | 127.0.0.1 |
| Port | 5432 |
| Database | smart_expiry |
| User | smart_expiry |
| Password | smart_expiry |
| JDBC URL | jdbc:postgresql://127.0.0.1:5432/smart_expiry |

这些是当前项目的默认值；如果自行改过 .env 或数据库账号，以实际值为准。
如提示 Download missing driver files，先下载驱动，再点击 Test Connection，成功后 Apply / OK。
展开 public schema 可查看 category、item、inventory_batch、flyway_schema_history。
如果 Database 工具窗口不可用，检查当前 IDE 是否提供并启用了 Database Tools and SQL 功能。

新建 Query Console，先执行：

```sql
SELECT 1 AS connection_ok;
SELECT current_database(), current_user;
SELECT * FROM category;
```

更多只读查询在 `postman/check-database.sql`。Postman 创建物品后可刷新 IDEA 数据表观察入库结果。
官方步骤：https://www.jetbrains.com/help/idea/postgresql.html

## 3. Postman 导入并发送请求

Import 以下两个文件：

- `postman/LoveStorage.postman_collection.json`
- `postman/Docker.postman_environment.json`

选择环境 `LoveStorage Docker`，其中 baseUrl 为 `http://localhost:18080`。
请求无需 Authorization；JSON 请求已设置 Content-Type。
按编号 01–10 依次 Send，或用集合 Run / Collection Runner 按默认顺序执行一次。
03 自动生成 clientId，并将响应 ID 保存为集合变量 itemId，后续请求自动引用。

| 编号 | 方法 / 路径 | 预期 |
|---|---|---|
| 01 | GET /api/v1/health | 200，data.status=UP |
| 02 | GET /api/v1/categories | 200，包含 food 分类 |
| 03 | POST /api/v1/items | 200，记录 itemId |
| 04 | GET /api/v1/items | 200，包含本次物品 |
| 05 | GET /api/v1/items/{{itemId}} | 200，返回详情 |
| 06 | PATCH /api/v1/items/{{itemId}} | 200，修改名称与重算到期日期 |
| 07 | PUT /api/v1/items/{{itemId}} | 200，标记 CONSUMED |
| 08 | POST /api/v1/items | 400，缺少日期信息，预期失败用例 |
| 09 | DELETE /api/v1/items/{{itemId}} | 200，软删除本次测试物品 |
| 10 | GET /api/v1/items/{{itemId}} | 404，预期删除后不可查询 |

每个请求都配置了 Post-response 测试断言。HTTP 400 / 404 的两个用例显示通过才是正确结果。
要观察 SQL 数据变化，请在 03 或 07 后暂停；09 后数据库记录仍存在但 deleted_at 非空，API 列表不再展示。
只在这个测试集合中管理 itemId；不要创建同名环境变量覆盖它。
Postman 环境说明：https://learning.postman.com/docs/sending-requests/variables/managing-environments/

## 4. 在 IDEA 启动 Java 并打断点

直接打开 `D:\Src\lovestorage\pom.xml` 作为 Maven 项目，Project SDK 选择 JDK 21，等待依赖同步。
新建 Application 或 Spring Boot Run Configuration：

- Main class：`com.smartexpiry.SmartExpiryApplication`
- Working directory：`D:\Src\lovestorage`
- 环境变量：

```text
SPRING_PROFILES_ACTIVE=default;DB_URL=jdbc:postgresql://127.0.0.1:5432/smart_expiry;DB_USERNAME=smart_expiry;DB_PASSWORD=smart_expiry;SERVER_PORT=18081
```

请使用 default profile；local profile 连接的是 H2 文件库。
删除运行配置中可能残留的 `--spring.profiles.active=local` 或 `-Dspring.profiles.active=local`，避免覆盖环境变量。
在 ItemController.create 或 ItemApplicationService.create 中打断点，点击 Debug 启动。
Postman 导入 `postman/IDEA.postman_environment.json`，切换至 `LoveStorage IDEA`，再执行 03 创建。
Postman 请求会进入 IDEA 启动的 18081 服务，断点命中后点击 Resume 继续。

Docker 后端 18080 与 IDEA 后端 18081 可以并存，并连接同一 PostgreSQL；它们看到相同数据。
普通 Run 不会停在断点上。修改源代码只影响 IDEA 启动的服务，Docker 内的 JAR 需重新打包并构建镜像。
如要调试 Docker 内的 Java 而非本机进程，请参考 DOCKER_DEBUG.md 的 5005 远程调试配置。

## 5. 常见问题

- Connection refused：确认 Docker Desktop 和容器已启动，核对 5432 / 18080 / 18081。
- password authentication failed：检查账号密码；已有卷的密码不会随 .env 修改自动变化。
- relation does not exist：核对数据库和 public schema，检查后端 Flyway 启动日志。
- Postman 请求连通但 IDEA 不进断点：是否仍选择 Docker 环境？断点调试需选 IDEA 的 18081。
- IDEA 能看到已删除记录：当前实现为软删除，检查 deleted_at。
- 云端 Postman 无法访问 localhost：使用桌面版，或在 Web 版中选择已连接的 Desktop Agent。
