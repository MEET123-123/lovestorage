# Docker 本地服务器调试

## 数据库在哪里

- 当前 local profile：`lovestorage/data/smart_expiry.mv.db`（H2 文件库）。
- HarmonyOS 手机本地副本：应用沙箱中的 ArkData `smart_expiry.db`，由系统管理。
- Docker 模式：真正的 PostgreSQL 17，库名 `smart_expiry`。数据存放于 Docker 命名卷 `smart_expiry_pgdata`（实际名称通常带 Compose 项目前缀），容器目录 `/var/lib/postgresql/data`。

H2 与 PostgreSQL 是独立数据库，切换配置不会自动迁移旧数据。新 PostgreSQL 库会由 Flyway 自动建表并初始化分类。

## 启动后端和数据库

前置：安装并启动 Docker Desktop，使用 Linux containers；`docker info` 能正常返回。

在 PowerShell 中执行：

```powershell
cd D:\Src\lovestorage
.\scripts\build.ps1
docker compose --profile server up -d --build
docker compose --profile server ps
docker compose logs -f backend
```

健康检查：

```powershell
Invoke-RestMethod http://localhost:18080/api/v1/health
```

前端“连接”地址填 `http://电脑局域网IP:18080`。默认端口与已有 H2 服务的 8080 分开，可同时运行。
后端容器通过 `postgres:5432` 连接数据库，不能用 localhost 指代另一容器。
现有前端变更服务地址会将本地记录重新排队，手动点击同步后可上传至新服务；这不等于迁移原 H2 的全部数据。

## 查看数据库

```powershell
docker compose exec postgres psql -U smart_expiry -d smart_expiry -c '\dt'
docker compose exec postgres psql -U smart_expiry -d smart_expiry -c 'SELECT id, name, lifecycle_status FROM item WHERE deleted_at IS NULL;'
docker volume ls
```

也可在数据库客户端中连接：主机 `127.0.0.1`、端口 `5432`、数据库/用户名/密码均默认 `smart_expiry`。
如在 `.env` 中改过 `DB_USERNAME`、`DB_PASSWORD` 或 `POSTGRES_PORT`，使用相应值。
已有数据卷的数据库密码不会因为修改环境变量而自动改变。

## IDE 断点调试

```powershell
docker compose -f docker-compose.yml -f docker-compose.debug.yml --profile server up -d --build
```

在 IntelliJ IDEA 新建 Remote JVM Debug，连接 `localhost:5005`。调试端口只对电脑本机开放。
修改 Java 源码后重新运行构建脚本和上述 Compose 命令，再重新附加调试器。

## 仅数据库放 Docker，Java 在 IDE 运行

```powershell
docker compose up -d postgres
.\scripts\run.ps1 -Profile default -Port 18080
```

或者在 IDEA 运行 `SmartExpiryApplication`，使用 default profile 配合数据库环境变量。此模式可直接使用 IDE 断点，无需远程调试。
不要同时启动两个占用 18080 端口的后端。

## 停止与保留数据

```powershell
docker compose --profile server down
```

正常 down 保留命名卷；不要添加 `-v`，除非明确要删除数据库。
Docker Desktop 的 Volumes 页面可查看数据卷；它不位于源码中的 H2 文件路径。

## 验证状态

2026-10-03 已实际构建并启动：Docker Desktop 4.93.0，Docker Engine 29.8.1，Compose 5.5.1。
后端镜像 `lovestorage-backend:latest`，容器 `lovestorage-backend-1`，对外端口 18080。
数据库容器 `smart-expiry-postgres`，PostgreSQL 17.11，健康检查通过。
Flyway V1 迁移成功，4 个系统分类已入库；Hibernate schema validate 通过。
实际前端 ApiClient 经主机 HTTP 适配器完成健康、创建、重复重试、更新、生命周期、详情、删除、重复删除检查。
数据库内只读查询确认测试记录已写入并软删除。
持久卷实际名称：`lovestorage_smart_expiry_pgdata`。

本机 Docker CLI 位于 `C:\Users\mx\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe`。
旧终端可能未继承更新后的 PATH，请重新打开终端或使用该完整路径。
默认网易镜像站返回 502，Docker Hub 直连也失败，因此项目默认使用 AWS Public ECR 的 Docker 官方镜像仓库。
可用 `.env` 中的 `POSTGRES_IMAGE` 和 `JAVA_IMAGE` 覆盖镜像来源，没有修改 Docker Desktop 的全局配置。
配置采用 Docker 官方的服务健康依赖和容器服务名通信方式：
https://docs.docker.com/compose/how-tos/startup-order/
https://docs.docker.com/compose/how-tos/networking/
